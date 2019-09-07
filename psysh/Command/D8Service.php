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
                new InputOption('depth', '', InputOption::VALUE_REQUIRED, 'Depth to parse.', 10),
                new InputOption('all', 'a', InputOption::VALUE_NONE, 'Include private and protected methods and properties.'),
            ])
            ->setDescription('Dump an object or primitive.')
            ->setHelp(
                <<<'HELP'
Dump an object or primitive.

This is like var_dump but <strong>way</strong> awesomer.

e.g.
<return>>>> dump $_</return>
<return>>>> dump $someVar</return>
<return>>>> dump $stuff->getAll()</return>
HELP
            );
    }

    /**
     * {@inheritdoc}
     */
    protected function execute(InputInterface $input, OutputInterface $output)
    {
        $depth  = $input->getOption('depth');
        $target = $this->resolveCode($input->getArgument('target'));
        $output->page($this->presenter->present($target, $depth, $input->getOption('all') ? Presenter::VERBOSE : 0));

        if (\is_object($target)) {
            $this->setCommandScopeVariables(new \ReflectionObject($target));
        }
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
