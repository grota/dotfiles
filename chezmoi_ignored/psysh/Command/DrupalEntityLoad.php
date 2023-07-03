<?php

namespace grota\Psysh\Command;

use Symfony\Component\Console\Input\InputArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Psy\Command\Command;

class DrupalEntityLoad extends Command
{
  /**
   * {@inheritdoc}
   */
  protected function configure(): void
  {
    $this
      ->setName('loadent')
      ->setDefinition([
        new InputArgument('entity_type_id', InputArgument::REQUIRED, 'The entity type id, e.g. node'),
        new InputArgument('entity_id', InputArgument::REQUIRED, 'The entity id, e.g. 123'),
      ])
      ->setDescription('Drupal entity loader');
  }

  /**
   * {@inheritdoc}
   */
  protected function execute(InputInterface $input, OutputInterface $output): int
  {
    $entity_type_id = $input->getArgument('entity_type_id');
    $entity_id = $input->getArgument('entity_id');
    /** @var \Drush\Psysh\Shell $app */
    $app = $this->getApplication();
    $e = '$e = Drupal::entityTypeManager()->getStorage(\'' . $entity_type_id . '\')->load(' . $entity_id . ');';
    $app->execute($e);
    $output->writeln('<comment>$e:</comment>');
    $app->addCode('$e', true);
    return 0;
  }
}
