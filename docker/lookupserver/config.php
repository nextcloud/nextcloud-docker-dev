<?php

// Lookup-Server Config

$CONFIG = [
	//DB
	'DB' => [
		'host' => 'localhost',
		'db' => 'lookup',
		'user' => 'lookup',
		'pass' => 'lookup',
	],

	// error verbose
	'ERROR_VERBOSE' => true,

    'LOG' => [
        'ENABLED' => true,
        'LEVEL' => 0,
        'FILE' => __DIR__ . '/../lookup.log',
        'FILE_MODE' => 0640,
        'DATE_FORMAT' => 'Y-m-d H:i:s',
        'DATE_TIMEZONE' => 'UTC',
        'HIDE_BACKTRACE' => false,
    ],

	// replication logfile
	'REPLICATION_LOG' => '/tmp/lookup_replication.log',

	// max user search page. limit the maximum number of pages to avoid scraping.
	'MAX_SEARCH_PAGE' => 10,

	// max requests per IP and 10min.
	'MAX_REQUESTS' => 10000,

	// credential to read the replication log. IMPORTANT!! SET TO SOMETHING SECURE!!
	'REPLICATION_AUTH' => 'foobar',

	// credential to read the slave replication log. Replication slaves are read only and don't get the authkey. IMPORTANT!! SET TO SOMETHING SECURE!!
	'SLAVEREPLICATION_AUTH' => 'slavefoobar',

	// the list of remote replication servers that should be queried in the cronjob
	'REPLICATION_HOSTS' => [
	],

	// ip black list. usefull to block spammers.
	'IP_BLACKLIST' => [
	],

	// spam black list. usefull to block spammers.
	'SPAM_BLACKLIST' => [
	],

	// Email sender address
	'EMAIL_SENDER' => 'admin@nextcloud.dev',

	// Public Server Url
	'PUBLIC_URL' => 'http://lookupserver',

	// does the lookup server run in a global scale setup
	'GLOBAL_SCALE' => true,

	// auth token
	'AUTH_KEY' => 'random-key',

    // twitter oauth credentials, needed to perform twitter verification
	'TWITTER' => [
		'CONSUMER_KEY' => '',
		'CONSUMER_SECRET' => '',
		'ACCESS_TOKEN' => '',
		'ACCESS_TOKEN_SECRET' => '',
	]
];


