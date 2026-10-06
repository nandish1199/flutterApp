# ElateFit

## Web push reminders

### In cPannel, under home2/elatec40/public_html/api/ there are 4 files:

- save_reminder.php: (NEEDED to save the reminder)
- test_cron.php: to test the cron_dispatcher php file. (Functionally not needed, its just for testing purpose)
- test_push.php: (Functionally not needed, its just for testing purpose)
- test_run_cron.php: to test the cron_dispatcher php file. (Functionally not needed, its just for testing purpose)

**Important**: The above test files contain database information that are not added now, whenever required add the following information and use it:
$cpanel_user = 'elatec40'; // <-- Replace with your cPanel username
$db_user = 'elatec40_dbuser'; // <-- Replace with your DB user
$db_pass     = 'N@ndish5787'; // <-- Replace with your DB password
$db_name = 'elatec40_water_reminders'; // <-- Replace with your DB name

### In cPannel, under home2/elatec40/php/ there are 3 files:

- cron_dispatcher.php: Used to trigger dispatcher in every minuit to send notification.
- save_reminder.php
- service-account.json: contains your all details like api keys and all.
