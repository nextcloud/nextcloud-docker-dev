<?php
$hostname = gethostname();
$primary = isset($_ENV['PRIMARY']) ? $_ENV['PRIMARY'] : '';
$virtualHost = isset($_ENV['VIRTUAL_HOST']) ? $_ENV['VIRTUAL_HOST'] : '';
$virtualHost = explode(".", $virtualHost);
if (count($virtualHost) > 0) {
	$hostname = array_shift($virtualHost);
}

$CONFIG=[
	'debug' => true,
	'profiler' => true,
	'apps_paths' => 
	array (
		0 => 
		array (
			'path' => '/var/www/html/apps',
			'url' => '/apps',
			'writable' => false,
		),
		1 => 
		array (
			'path' => '/var/www/html/apps-extra',
			'url' => '/apps-extra',
			'writable' => false,
		),
		2 => 
		array (
			'path' => '/var/www/html/apps-shared',
			'url' => '/apps-shared',
			'writable' => false,
		),
		3 =>
		array (
			'path' => '/var/www/html/apps-writable',
			'url' => '/apps-writable',
			'writable' => true,
		),
	),

	// allow local remote senders
	'allow_local_remote_servers' => true,

	// config for mailhog
	'mail_from_address' => 'admin',
	'mail_smtpmode' => 'smtp',
	'mail_sendmailmode' => 'smtp',
	'mail_domain' => 'localhost',
	'mail_smtphost' => 'mail',
	'mail_smtpport' => '1025',

	'skeletondirectory' => '/skeleton',

	'setup_create_db_user' => false,

	'debug' => true,
	'loglevel' => 2,

	// 'htaccess.RewriteBase' => '/',
	'log_query' => false,
	'query_log_file' => '/shared/log/querylog-' . $hostname .'.log',
	'query_log_file_requestid' => 'yes',

	'diagnostics.logging' => false,
	'diagnostics.logging.threshold' => 0,
	'log.condition' => [
        'apps' => ['diagnostics', 'admin_audit'],
	],

    // federation and globalscale to work with self-signed certificates
    'sharing.federation.allowSelfSignedCertificates' => true,
    'gss.selfsigned.allow' => true,
];


if ($primary === 'minio') {
	$CONFIG += [
		'objectstore' =>
		array (
			'class' => 'OC\\Files\\ObjectStore\\S3',
			'arguments' =>
			array (
				'bucket' => 'nc-' . $hostname,
				'key' => 'nextcloud',
				'secret' => 'nextcloud',
				'hostname' => 'minio',
				'port' => '9000',
				'use_ssl' => false,
				'use_path_style' => true,
				'autocreate' => true,
				'verify_bucket_exists' => true,
			),
		)
	];
}

if ($primary === 'minio-multibucket') {
	$CONFIG += [
		'objectstore_multibucket' => array(
			'class' => 'OC\\Files\\ObjectStore\\S3',
			'arguments' => array(
				// optional, defaults to 64
				'num_buckets' => 64,
				// n integer in the range from 0 to (num_buckets-1) will be appended
				'bucket' => 'nc-' . $hostname,
				'key' => 'nextcloud',
				'secret' => 'nextcloud',
				'hostname' => 'minio',
				'port' => '9000',
				'use_ssl' => false,
				'use_path_style' => true,
			),
		),
	];
}


if ($primary === 'rustfs') {
	$CONFIG += [
		'objectstore' =>
		array (
			'class' => 'OC\\Files\\ObjectStore\\S3',
			'arguments' =>
			array (
				'bucket' => 'nc-' . $hostname,
				'key' => 'nextcloud',
				'secret' => 'nextcloud',
				'hostname' => 'rustfs.local',
				'port' => '80',
				'proxy' => 'rustfs:9000',
				'use_ssl' => false,
				'use_path_style' => true,
				'use_presigned_url' => true,
				'autocreate' => true,
				'verify_bucket_exists' => true,
			),
		)
	];
}

if ($primary === 'rustfs-multibucket') {
	$CONFIG += [
		'objectstore_multibucket' => array(
			'class' => 'OC\\Files\\ObjectStore\\S3',
			'arguments' => array(
				// optional, defaults to 64
				'num_buckets' => 64,
				// n integer in the range from 0 to (num_buckets-1) will be appended
				'bucket' => 'nc-' . $hostname,
				'key' => 'nextcloud',
				'secret' => 'nextcloud',
				'hostname' => 'rustfs.local',
				'port' => '80',
				'proxy' => 'rustfs:9000',
				'use_presigned_url' => true,
				'use_ssl' => false,
				'use_path_style' => true,
			),
		),
	];
}
