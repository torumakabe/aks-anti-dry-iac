#!/bin/bash

diff -ru ../../flux/apps/blue ../../flux/apps/green
diff -ru ../../flux/clusters/blue ../../flux/clusters/green --exclude="flux-system"
diff -ru ../../flux/infrastructure/blue ../../flux/infrastructure/green
diff -ru ../../flux/scripts/blue ../../flux/scripts/green
