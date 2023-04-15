<?php

namespace grota\Psysh\Command;

use Psy\Input\CodeArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Psy\Command\Command;

/**
 * D8 Service helper.
 */
class D8Service extends Command
{

  /**
   * {@inheritdoc}
   */
  protected function configure(): void
  {
    $this
      ->setName('serv')
      ->setDefinition([
        new CodeArgument('service_name', CodeArgument::REQUIRED, 'The D8 service name'),
      ])
      ->setDescription('Drupal service helper');
  }

  /**
   * {@inheritdoc}
   */
  protected function execute(InputInterface $input, OutputInterface $output): int
  {
    $name = $input->getArgument('service_name');
    /** @var \Drush\Psysh\Shell $app */
    $app = $this->getApplication();
    $serviceCommand = '$s = Drupal::service(\'' . $name . '\');';
    $app->execute($serviceCommand);
    $output->writeln('<comment>Interfaces:</comment>');
    $app->addCode('class_implements($s)', true);
    return 0;
  }
}
