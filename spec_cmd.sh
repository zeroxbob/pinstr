#!/usr/bin/env bash
source ~/.bashrc
chruby 3.3.5

bundle exec rspec "$@"
