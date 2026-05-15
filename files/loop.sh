#!/bin/bash
# Usage: ./loop.sh [plan|build] [max_iterations] [--model name]
# Examples:
#   ./loop.sh build 20 --model sonnet
#   MODEL=haiku ./loop.sh plan 5

# 1. Set Defaults
MODE="build"
PROMPT_FILE="PROMPT_build.md"
MAX_ITERATIONS=0
MODEL="${MODEL:-opus}" # Uses environment variable if set, otherwise "opus"

# 2. Flexible Argument Parsing
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
  -m | --model)
    MODEL="$2"
    shift # past argument
    shift # past value
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
    POSITIONAL_ARGS+=("$1") # save positional arg (likely max_iterations)
    shift
    ;;
  esac
done

# Restore positional parameters to handle max_iterations
set -- "${POSITIONAL_ARGS[@]}"

# Handle the max_iterations logic from your original script
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

  # Run iteration using the $MODEL variable
  cat "$PROMPT_FILE" | claude -p \
    --dangerously-skip-permissions \
    --output-format=stream-json \
    --model "$MODEL" \
    --verbose

  git push origin "$CURRENT_BRANCH" || {
    echo "Failed to push. Creating remote branch..."
    git push -u origin "$CURRENT_BRANCH"
  }

  ITERATION=$((ITERATION + 1))
  echo -e "\n\n======================== LOOP $ITERATION ========================\n"
done

