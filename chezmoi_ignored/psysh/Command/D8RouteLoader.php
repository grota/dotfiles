<?php

namespace grota\Psysh\Command;

use Psy\Input\CodeArgument;
use Psy\VarDumper\Presenter;
use Psy\VarDumper\PresenterAware;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;
use Psy\Command\ReflectingCommand;

/**
 * D8 Route loader helper.
 */
class D8RouteLoader extends ReflectingCommand implements PresenterAware
{
    private $presenter;

    /**
     * PresenterAware interface.
     *
     * @param Presenter $presenter
     */
    public function setPresenter(Presenter $presenter)
    {
        $this->presenter = $presenter;
    }

    /**
     * {@inheritdoc}
     */
    protected function configure()
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
    protected function execute(InputInterface $input, OutputInterface $output)
    {
      $name = $input->getArgument('route_name');
      $this->getApplication()->addInput('$route_provider = Drupal::service(\'router.route_provider\'); $route=$route_provider->getRouteByName(\'' . $name . '\');');
      $this->getApplication()->addInput('dump -a $route');
    }

    /**
     * @deprecated Use `resolveCode` instead
     *
     * @param string $name
     *
     * @return mixed
     */
    protected function resolveTarget($name)
    {
        @\trigger_error('`resolveTarget` is deprecated; use `resolveCode` instead.', E_USER_DEPRECATED);

        return $this->resolveCode($name);
    }
}

