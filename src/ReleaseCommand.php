<?php

declare(strict_types=1);

namespace Vaslv\Release;

use Composer\Command\BaseCommand;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;

class ReleaseCommand extends BaseCommand
{
    protected function configure(): void
    {
        $this
            ->setName('release')
            ->setDescription('Interactively pick the next semver version, then commit, tag and push it');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $script = \dirname(__DIR__) . '/bin/release';

        if (!is_file($script)) {
            $output->writeln(sprintf('<error>Release script not found: %s</error>', $script));

            return 1;
        }

        // passthru() shares the terminal with the script, keeping its prompts interactive.
        // Pre-set the exit code: passthru() leaves it untouched when the process fails to launch.
        $exitCode = 1;
        passthru('bash ' . escapeshellarg($script), $exitCode);

        return $exitCode;
    }
}
