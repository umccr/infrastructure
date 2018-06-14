

# custom overwrite of cd command
function path_actions () {
  if [ ! $CURRENT_DIR = "" ]; then
    . $CURRENT_DIR/.env/cleanup.sh
    unset CURRENT_DIR
  fi

  if [ -d .env ]; then
    export CURRENT_DIR=`pwd`
    . .env/setup.sh
  fi
}

# override the builtin cd
function cd () {
  builtin cd "$@" && path_actions;
}
