<?php
include_once '../grota/psysh/Command/D8Service.php';
include_once '../grota/psysh/Command/D8RouteLoader.php';
include_once '../grota/psysh/Command/DrupalEntityLoad.php';
return [
  'commands' => [
    new grota\Psysh\Command\D8Service,
    new grota\Psysh\Command\D8RouteLoader,
    new grota\Psysh\Command\DrupalEntityLoad,
  ],
];
