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
 * Dump an object or primitive.
 *
 * This is like var_dump but *way* awesomer.
 */
class D8Service extends ReflectingCommand implements PresenterAware
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
            ->setName('serv')
            ->setDefinition([
                new CodeArgument('target', CodeArgument::REQUIRED, 'A target object or primitive to dump.'),
            ])
            ->setDescription('Drupal service helper');
    }

    /**
     * {@inheritdoc}
     */
    protected function execute(InputInterface $input, OutputInterface $output)
    {
      $name = $input->getArgument('target');
      $this->getApplication()->addInput('$s = Drupal::service(\'' . $name . '\'); class_implements($s);');
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
