#!/usr/bin/env bash

diff -ru ../../flux/apps/blue ../../flux/apps/green
diff -ru ../../flux/clusters/blue ../../flux/clusters/green --exclude="flux-system"
diff -ru ../../flux/infrastructure/blue ../../flux/infrastructure/green
