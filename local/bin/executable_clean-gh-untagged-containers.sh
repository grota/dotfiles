#!/usr/bin/env bash

USER_CONTAINER_PACKAGE=$(gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /user/packages?package_type=container --jq '.[].name' | fzf)

gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /users/grota/packages/container/"$USER_CONTAINER_PACKAGE"/versions | jq '.[] | select(.metadata.container.tags | length == 0) | .id' | while read -r id; do
    echo "Deleting container version: $id"
    gh api --method DELETE -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /users/grota/packages/container/"$USER_CONTAINER_PACKAGE"/versions/"$id"
done
