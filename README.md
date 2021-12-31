# deb-postgres

Postgres database based on Debian Bullseye Slim with useful modules added.

The inspiration for this image comes from [frodenas postgres](https://github.com/frodenas/docker-postgresql) but updated for the latest postgres 14 and bullseye slim.

The following modules are installed:

- [Postgresql contrib](https://www.postgresql.org/docs/14/contrib.html) - Awesome PostgreSQL extensions
- [PostGIS](https://postgis.net/) - PostGIS extension
- [pgRouting](https://pgrouting.org/) - PostgreSQL PostGIS routing extension
- [pgTAP](https://pgtap.org/) - Postgres unit testing on steriods
- [pg_cron](https://github.com/citusdata/pg_cron) - PostgreSQL cron extension
- [pgjwt](https://github.com/michelp/pgjwt) - PostgreSQL JSON Web Token extension
- [plv8](https://github.com/plv8/plv8) - Javascript runtime extension

This is intended to be a developer friendly postgres; if a production image is required, we suggest [Supabase](https://github.com/supabase/postgres).

___

If you appreciate my work, then please consider buying me a beer :D

[![PayPal donation](https://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/donate?hosted_button_id=KKQ4LNMEDVUPN)
