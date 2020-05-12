#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# FIGURE OUT THE SHELL
if [[ "$SHELL" == *'/zsh' ]]; then
    shell_config_path="$HOME/.zshrc"
    shell_name="zsh"
elif [[ "$SHELL" == *'/bash' ]]; then # use * wildcards since the specific shell path can differ (for example mine was /usr/local/bin/bash not /bin/bash)
    shell_config_path="$HOME/.bashrc"
    shell_name="bash"
else
    printf "${RED}ERROR: Unidentified shell.${NC}\n"
    exit 1
fi

# MAKE SURE SSH KEYS HAVE BEEN SETUP
prompt="Before continuing, did you setup an ssh key with github? https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent (Y to continue, N to cancel): "
printf "${GREEN}${prompt}${NC}"

# this only works for bash
read -n 1 -r # use read -k -r if running with zsh

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    printf "\n${RED}ERROR: Please do that first, then re-run this script.${NC}\n"
    exit 1
else
    printf "\n${GREEN}Proceeding...${NC}\n"
fi

printf "${GREEN}We have detected you are using the $shell_name shell with config $shell_config_path${NC}\n"

# Make the shell config file if it doesn't exist yet
if [ ! -f "$shell_config_path" ]; then
    touch $shell_config_path
fi

grep -q -F '# DEVELOPMENT #' $shell_config_path

if [ $? -ne 0 ]; then
    printf "\n${GREEN}Adding necessary exports and aliases to $shell_config_path${NC}\n"

    printf '\n' >> $shell_config_path
    printf '###############\n' >> $shell_config_path
    printf '# DEVELOPMENT #\n' >> $shell_config_path
    printf '###############\n' >> $shell_config_path
    printf 'export PATH="/usr/local/bin:$PATH"\n' >> $shell_config_path
    printf 'export PATH="/usr/local/sbin:$PATH"\n' >> $shell_config_path
    printf '\n' >> $shell_config_path
    printf 'export PATH="$HOME/.composer/vendor/bin:$PATH"\n' >> $shell_config_path
    printf 'export PATH="/usr/local/opt/mysql@5.7/bin:$PATH"\n' >> $shell_config_path
    printf '\n' >> $shell_config_path
    printf 'alias phpunit="vendor/bin/phpunit"\n' >> $shell_config_path
    printf 'alias phpstan="vendor/bin/phpstan"\n' >> $shell_config_path
    printf 'alias composer="COMPOSER_MEMORY_LIMIT=-1 composer"\n' >> $shell_config_path
    printf 'alias art="php artisan"\n' >> $shell_config_path
    printf 'alias portal="cd $HOME/Code/portal"\n' >> $shell_config_path
    printf 'alias grep="grep --color=always"\n' >> $shell_config_path

    source $shell_config_path
fi

# DO WE NEED TO INSTALL NVM?
is_node_detected=$(node -v 2> /dev/null)

if [[ $is_node_detected ]]; then
    printf "\n${GREEN}node.js is already installed${NC}\n\n"

    printf "${GREEN}node.js version:${NC}"
    printf " $(node -v)"

    printf "\n${GREEN}npm version:${NC}"
    printf " $(npm -v)\n"
else
    printf "\n${GREEN}node.js is not installed - proceeding to install https://github.com/nvm-sh/nvm${NC}\n"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh)"

    source $shell_config_path

    printf "\n${GREEN}nvm is installed, proceeding to install node.js and npm${NC}\n"

    # INSTALL NODE v10.17.0
    nvm install 10.17.0
    nvm alias default 10.17.0
fi

# DO WE NEED TO INSTALL HOMEBREW?
is_brew_detected=$(brew -v 2> /dev/null)

if [[ $is_brew_detected ]]; then
    printf "\n${GREEN}homebrew is already installed${NC}\n"
    printf "$(brew -v)\n"
else
    printf "\n${GREEN}homebrew is not installed - proceeding to install https://brew.sh/${NC}\n"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

# UPDATE BREW
printf "\n${GREEN}brew update${NC}\n"
brew update

# DO WE NEED TO INSTALL PHP?
is_php_detected=$(brew list php 2> /dev/null)

if [[ $is_php_detected ]]; then
    printf "\n${GREEN}php is already installed${NC}\n"
    printf "$(php -v)\n"
else
    printf "\n${GREEN}php is not installed - proceeding to install php@7.4${NC}\n"
    brew install php

    # SYMLINK PHP EXECUTABLE
    ln -s /usr/local/opt/php/bin/php /usr/local/bin/php
fi

# DO WE NEED TO INSTALL MySQL?
brew list mysql@5.7> /dev/null

if [ $? -ne 0 ]; then
    printf "\n${GREEN}MySQL not installed - proceeding to install${NC}\n"
    brew install mysql@5.7
    brew services start mysql@5.7
else
    printf "\n${GREEN}mysql@5.7 is already installed${NC}\n"
fi

# DO WE NEED TO INSTALL COMPOSER?
is_composer_detected=$(composer --version 2> /dev/null)

if [[ $is_composer_detected ]]; then
    printf "\n${GREEN}composer is already installed${NC}\n"
    printf "$(composer --version)\n"
else
    EXPECTED_CHECKSUM="$(wget -q -O - https://composer.github.io/installer.sig)"
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]
    then
        >&2 echo 'ERROR: Invalid composer installer checksum'
        rm composer-setup.php
        exit 1
    fi

    php composer-setup.php --quiet
    rm composer-setup.php
    mv composer.phar /usr/local/bin/composer
fi

# DO WE NEED TO INSTALL LARAVEL/VALET?
is_valet_detected=$(valet --version 2> /dev/null)

if [[ $is_valet_detected ]]; then
    printf "\n${GREEN}valet is already installed${NC}\n"
    printf "$(valet --version)\n"
else
    composer global require laravel/valet
    valet install
fi

# DO WE NEED TO INSTALL REDIS?
is_redis_detected=$(brew list redis 2> /dev/null)

if [[ $is_redis_detected ]]; then
    printf "\n${GREEN}redis is already installed${NC}\n"
else
    printf "\n${GREEN}redis is not installed - proceeding to install${NC}\n"
    brew install redis
    brew services start redis
fi

# GET THE MYSQL PASSWORD
printf "Enter your mysql root password (most likely it is blank or something simple like 'pass':\n"
read -rs password </dev/tty

# MAKE SURE THE APPROPRIATE DATABASES EXIST
mysql --user="root" --password="$password" --execute="CREATE DATABASE IF NOT EXISTS portal; CREATE DATABASE IF NOT EXISTS test;"

# SETUP PROJECT DIRECTORY
if [ ! -d $HOME/Code ]; then
  mkdir $HOME/Code
fi

cd "$HOME/Code" || exit 1

# CLONE THE PORTAL REPO
if [ ! -d portal ]; then
  printf "\n${GREEN}cloning the portal repo${NC}\n"
  git clone git@github.com:TAGResources/portal.git
fi;

valet paths | grep -q -F "$HOME/Code"

# IS VALET SERVING THE PROJECT?
if [ $? -ne 0 ]; then
  printf "\n${GREEN}Telling Laravel Valet to serve projects in ~/Code${NC}\n"
  valet park
fi

cd portal || exit 1

if [ ! -f ".env" ]; then
    printf "\n${GREEN}Creating standard .env file${NC}\n"
    cp .env.example .env
fi

printf "\n${GREEN}Preparing assets and 3rd party libraries${NC}\n"
composer install
npm install
npm run dev

printf "\n\n${GREEN}Done with setup! Go to portal.test in your browser to test it out! If there are any issues, double check the values in your .env or ask another dev for help.${NC}\n"