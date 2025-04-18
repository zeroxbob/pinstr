#!/usr/bin/env bash
# Source your environment so that chruby is available
source ~/.bashrc  
chruby 3.3.5

# Then pass any arguments to Rails directly
bundle exec rails "$@"
