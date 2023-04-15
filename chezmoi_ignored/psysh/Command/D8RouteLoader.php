<?php

namespace grota\Psysh\Command;

use Psy\Input\CodeArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Psy\Command\Command;

/**
 * D8 Route loader helper.
 */
class D8RouteLoader extends Command
{
  /**
   * {@inheritdoc}
   */
  protected function configure(): void
  {
    $this
      ->setName('loadroute')
      ->setDefinition([
        new CodeArgument('route_name', CodeArgument::REQUIRED, 'The D8 route name'),
      ])
      ->setDescription('Drupal route loader helper');
  }

  /**
   * {@inheritdoc}
   */
  protected function execute(InputInterface $input, OutputInterface $output): int
  {
    $name = $input->getArgument('route_name');
    /** @var \Drush\Psysh\Shell $app */
    $app = $this->getApplication();
    $strexecute = <<<'END'
$route_provider = Drupal::service('router.route_provider'); $route=$route_provider->getRouteByName('
END;
    $strexecute .= $name . <<<'END'
');
END;
    $app->execute($strexecute);
    $app->addInput('dump -a $route', true);
    return 0;
  }
}
