#!/usr/bin/env bash

diff -ru ../../../terraform/blue ../../../terraform/green --exclude=".terraform" --exclude="terraform*" --exclude=".terraform*"
