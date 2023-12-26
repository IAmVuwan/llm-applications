set -eu

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

#if [ ! -d "$HOME/miniforge3" ]; then
#
#  # check os architecture and download the appropriate miniforge installer
#  if [ "$(uname -m)" = "x86_64" ]; then
#    curl -L -O https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
#    sh Miniforge3-Linux-x86_64.sh
#    rm Miniforge3-Linux-x86_64.sh
#    exit 0
#  elif [ "$(uname -m)" = "arm64" ]; then
#    curl -L -O https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-arm64.sh
#    sh Miniforge3-MacOSX-arm64.sh
#    rm Miniforge3-MacOSX-arm64.sh
#    exit 0
#  fi
#
#fi
#
#SHELL_NAME=$(basename "$SHELL")
#eval "$("$HOME/miniforge3/bin/conda" "shell.$SHELL_NAME" hook)"
#
#if [ ! -d "$HOME/miniforge3/envs/pt" ]; then
#  conda create --name="pt" "python<3.11"
#  conda activate pt
#  conda install pip
#  exit 0
#else
#  conda activate pt
#fi

export EFS_DIR=$SCRIPT_DIR/build/efs
mkdir -p "$EFS_DIR"

check_arg() {
  local val_arg="$1"

  for arg in "${@:2}"; do
    if [ "$arg" = "$val_arg" ]; then
      return 0 # Success: found
    fi
  done

  return 1 # Failure: not found
}

if check_arg "--infra" "$1"; then
  pulumi up
fi

if check_arg "--init" "$1"; then
  pip install -r requirements.txt
  pip install notebook
  jupyter notebook
fi

if check_arg "--ray" "$1"; then
  pip install "ray[data,train,tune,serve]"
fi

if check_arg "--docker" "$1"; then
  docker compose up -d
  docker compose logs -f
fi

if check_arg "--cluster" "$1"; then
  pip install boto3
  ray up cluster.yaml
fi

if check_arg "--cluster-attach" "$1"; then
  ray attach cluster.yaml
fi

if check_arg "--cluster-down" "$1"; then
  ray down cluster.yaml
fi

if check_arg "--data" "$1"; then
  : "$EFS_DIR"
  rm -rf "$EFS_DIR"
  mkdir -p "$EFS_DIR"
  mkdir -p "$EFS_DIR/sql_dumps"
  wget -e robots=off --recursive --no-clobber --page-requisites \
    --html-extension --convert-links --restrict-file-names=unix \
    --domains docs.ray.io --no-parent --accept=html \
    -P "$EFS_DIR" https://docs.ray.io/en/master/
fi

if check_arg "--connect" "$1"; then
  if [[ -z "$2" || -n "$2" ]];
  then
      echo "Please provide the private key as the second argument"
      exit
  fi
  if [[ -z "$3" || -n "$3" ]];
  then
      echo "Please provide the ec2 instance public dns as the third argument"
      exit
  fi
  ssh -i "$2" -o IdentitiesOnly=yes -L 8888:localhost:8888 "$3"
fi
