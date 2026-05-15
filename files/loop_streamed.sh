#!/bin/bash
set -o pipefail

# 1. Defaults
MODE="build"
PROMPT_FILE="PROMPT_build.md"
MAX_ITERATIONS=0
MODEL="${MODEL:-opus}" # Defaults to opus unless environment variable is set

# 2. Argument Parsing
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
  -m | --model)
    MODEL="$2"
    shift 2
    ;;
  plan)
    MODE="plan"
    PROMPT_FILE="PROMPT_plan.md"
    shift
    ;;
  build)
    MODE="build"
    PROMPT_FILE="PROMPT_build.md"
    shift
    ;;
  *)
    POSITIONAL_ARGS+=("$1")
    shift
    ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # Restore non-flag arguments

# Handle max_iterations logic
if [[ "$1" =~ ^[0-9]+$ ]]; then
  MAX_ITERATIONS=$1
fi

ITERATION=0
CURRENT_BRANCH=$(git branch --show-current)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mode:    $MODE"
echo "Model:   $MODEL"
echo "Prompt:  $PROMPT_FILE"
echo "Branch:  $CURRENT_BRANCH"
[ $MAX_ITERATIONS -gt 0 ] && echo "Max:     $MAX_ITERATIONS iterations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Error: $PROMPT_FILE not found"
  exit 1
fi

while true; do
  if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
    echo "Reached max iterations: $MAX_ITERATIONS"
    break
  fi

  FULL_PROMPT="$(cat "$PROMPT_FILE")

Execute the instructions above."

  echo "⏳ Running Claude ($MODEL)..."
  echo ""

  # Stream JSON with partial messages, parse for readable output
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # Use the $MODEL variable here
  claude -p "$FULL_PROMPT" \
    --dangerously-skip-permissions \
    --model "$MODEL" \
    --verbose \
    --output-format stream-json \
    --include-partial-messages | node "$SCRIPT_DIR/parse_stream.js"

  echo ""
  echo "✅ Claude iteration complete"

  git push origin "$CURRENT_BRANCH" || {
    echo "Failed to push. Creating remote branch..."
    git push -u origin "$CURRENT_BRANCH"
  }

  ITERATION=$((ITERATION + 1))
  echo -e "\n\n======================== LOOP $ITERATION ========================\n"
done

