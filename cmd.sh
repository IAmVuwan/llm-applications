#!/bin/bash

set -eu

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null 2>&1 && pwd)

check_arg() {
  local val_arg="$1"

  for arg in "${@:2}"; do
    if [ "$arg" = "$val_arg" ]; then
      return 0 # Success: found
    fi
  done

  return 1 # Failure: not found
}

run_goals() {
  local goals=("$@")

  if check_arg "--venv" "${goals[@]}"; then
    python3 -m venv "${SCRIPT_DIR}/.venv"
    source "${SCRIPT_DIR}/.venv/bin/activate"
    pip install -r "${SCRIPT_DIR}/requirements.txt"
  fi

  if check_arg "--docker-pgvector" "${goals[@]}"; then
    docker compose -f "${SCRIPT_DIR}/docker-compose.yaml" up -d
    docker compose -f "${SCRIPT_DIR}/docker-compose.yaml" logs
  fi

  if check_arg "--pgvector" "${goals[@]}"; then
    chmod +x setup-pgvector.sh
    ./setup-pgvector.sh
  fi

  if check_arg "--env" "${goals[@]}"; then
    cat <<EOF >.env
OPENAI_API_BASE="https://api.openai.com/v1"
OPENAI_API_KEY=""  # https://platform.openai.com/account/api-keys
ANYSCALE_API_BASE="https://api.endpoints.anyscale.com/v1"
ANYSCALE_API_KEY=""  # https://app.endpoints.anyscale.com/credentials
DB_CONNECTION_STRING="dbname=api user=myuser host=localhost password=ChangeMe port=5433"
EOF
  fi

  export EFS_DIR=$SCRIPT_DIR/build/efs

  if check_arg "--notebook" "${goals[@]}"; then
    source "${SCRIPT_DIR}/.venv/bin/activate"
    jupyter notebook
  fi

  if check_arg "--notebook-remote" "${goals[@]}"; then
    source "${SCRIPT_DIR}/.venv/bin/activate"
    jupyter notebook
    nohup jupyter notebook --ip=0.0.0.0 --NotebookApp.allow_origin='*' --NotebookApp.disable_check_xsrf=True --NotebookApp.token='P@ssw0rd' --port 8888 \
      >"notebook.log" </dev/null 2>&1 &

    tail -f "notebook.log"
  fi

  if check_arg "--connect-notebook" "${goals[@]}"; then
    if [[ -z "$2" || -n "$2" ]];
    then
        echo "Please provide the ec2 instance public dns as the second argument"
        exit
    fi
    ssh -o IdentitiesOnly=yes -L 8888:localhost:8888 "$2"
  fi

  if check_arg "--load-data" "${goals[@]}"; then
    : "$EFS_DIR"
    mkdir -p "$EFS_DIR"
    wget -e robots=off --recursive --no-clobber --page-requisites \
      --html-extension --convert-links --restrict-file-names=windows \
      --domains docs.ray.io --no-parent --accept=html \
      -P "$EFS_DIR" https://docs.ray.io/en/master/
  fi

  if check_arg "--ray-start" "${goals[@]}"; then
    pip install -U "ray[data,train,tune,serve]"
    ray start --head
  fi

  if check_arg "--infra-up" "${goals[@]}"; then
    # check pulumi is installed
    if ! command -v pulumi &> /dev/null
    then
        echo "pulumi could not be found"
        brew install pulumi/tap/pulumi
        exit
    fi
    pulumi up
  fi

  if check_arg "--infra-down" "${goals[@]}"; then
    pulumi down
  fi

}

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTION]...

Options:
  -h, --help                Show this help and exit
  --venv                    Create a virtual environment and install dependencies
  --start-pgvector          Start pgvector docker container
EOF
}

main() {
  if [ $# -eq 0 ]; then
    usage
    exit 0
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      *)
        run_goals "$@"
        ;;
    esac
    shift
  done
}

main "$@"
