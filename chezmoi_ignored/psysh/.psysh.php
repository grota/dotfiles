<?php
include_once '../grota/psysh/Command/D8Service.php';
include_once '../grota/psysh/Command/D8RouteLoader.php';
include_once '../grota/psysh/Command/DrupalEntityLoad.php';

// For the `doc` command to easily find the php manual (in docker containers).
$_SERVER['XDG_DATA_HOME'] = getcwd() . '/../grota';

return [
  'commands' => [
    new grota\Psysh\Command\D8Service,
    new grota\Psysh\Command\D8RouteLoader,
    new grota\Psysh\Command\DrupalEntityLoad,
  ],
];
