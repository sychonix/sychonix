GREEN="\e[1m\e[1;32m" # green color
RED="\e[1m\e[1;31m" # red color
BLUE='\033[0;34m'   # blue color
YELLOW='\033[1;33m'   # warna kuning
PURPLE='\033[0;35m'   # warna ungu
CYAN='\033[0;36m'     # warna cyan
WHITE='\033[1;37m'    # warna putih
ORANGE='\033[0;33m'   # warna oranye
PINK='\033[1;35m'     # warna pink
NC="\e[0m"          # no color


function printLogo {
  bash <(curl -s https://raw.githubusercontent.com/sychonix/sychonix/main/autointall/logo.sh)
}

function printLine {
  echo "------------------------------------------------------------------------------------"
}

function printGreen {
  echo -e "${RED}${1}${NC}"
}

function printRed {
  echo -e "${PINK}${1}${NC}"
}

function printBlue {
  echo -e "${BLUE}${1}${NC}"
}

function addToPath {
  source $HOME/.bash_profile
  PATH_EXIST=$(grep "${1}" $HOME/.bash_profile)
  if [ -z "$PATH_EXIST" ]; then
    echo "export PATH=\$PATH:${1}" >> $HOME/.bash_profile
  fi
}
