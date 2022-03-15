#!/usr/bin/env bash

diff -ru ../../flux/apps/blue ../../flux/apps/green
diff -ru ../../flux/apps/blue-dev-test ../../flux/apps/green-dev-test
diff -ru ../../flux/clusters/blue ../../flux/clusters/green --exclude="flux-system"
diff -ru ../../flux/clusters/blue-dev-test ../../flux/clusters/green-dev-test --exclude="flux-system"
diff -ru ../../flux/infrastructure/blue ../../flux/infrastructure/green
diff -ru ../../flux/infrastructure/blue-dev-test ../../flux/infrastructure/green-dev-test
