#!/usr/bin/env php
<?php

declare(strict_types=1);

const CONTAINER_ROOT = '/var/www/html';

function findRoot(string $start): ?string
{
    $start = is_dir($start) ? $start : dirname($start);
    $start = realpath($start) ?: $start;

    foreach (['artisan', 'composer.json', '.git'] as $marker) {
        $dir = $start;
        while (true) {
            if (file_exists($dir.DIRECTORY_SEPARATOR.$marker)) {
                return $dir;
            }
            $parent = dirname($dir);
            if ($parent === $dir) {
                break;
            }
            $dir = $parent;
        }
    }
    return null;
}

function envFile(string $root): array
{
    $values = [];
    $path = $root.DIRECTORY_SEPARATOR.'.env';
    if (!is_readable($path)) {
        return $values;
    }
    foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $line) {
        if (!preg_match('/^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*?)\s*$/', $line, $match)) {
            continue;
        }
        $values[$match[1]] = trim($match[2], "\"'");
    }
    return $values;
}

function inRoot(string $path, string $root): bool
{
    $path = str_replace('\\', '/', $path);
    $root = rtrim(str_replace('\\', '/', $root), '/');
    return $path === $root || str_starts_with($path, $root.'/');
}

function containerPath(string $path, string $root): string
{
    $absolute = realpath($path) ?: $path;
    if (!inRoot($absolute, $root)) {
        return $path;
    }
    return CONTAINER_ROOT.substr(str_replace('\\', '/', $absolute), strlen(str_replace('\\', '/', $root)));
}

$args = array_slice($argv, 1);
$rootCandidate = getcwd() ?: '.';
foreach ($args as $arg) {
    if ($arg !== '' && $arg[0] === '/' && !str_starts_with($arg, '--')) {
        $rootCandidate = $arg;
        break;
    }
}
$root = findRoot($rootCandidate);
if ($root === null) {
    fwrite(STDERR, "PHPUnit bridge: no composer project root found\n");
    exit(2);
}

$sail = $root.DIRECTORY_SEPARATOR.'vendor/bin/sail';
$localPhpunit = $root.DIRECTORY_SEPARATOR.'vendor/bin/phpunit';
$usesSail = file_exists($sail);
$junitTarget = null;
$junitContainer = null;
$rewritten = [];

for ($i = 0; $i < count($args); $i++) {
    $arg = $args[$i];
    if ($usesSail && str_starts_with($arg, '--log-junit=')) {
        $junitTarget = substr($arg, strlen('--log-junit='));
        continue;
    }
    if ($usesSail && $arg === '--log-junit' && isset($args[$i + 1])) {
        $junitTarget = $args[++$i];
        continue;
    }
    $rewritten[] = $usesSail && str_starts_with($arg, '/') ? containerPath($arg, $root) : $arg;
}

if ($usesSail && $junitTarget !== null) {
    $cache = $root.DIRECTORY_SEPARATOR.'storage/framework/cache/neotest';
    if (!is_dir($cache) && !mkdir($cache, 0777, true) && !is_dir($cache)) {
        fwrite(STDERR, "PHPUnit bridge: cannot create $cache\n");
        exit(2);
    }
    $junitHost = $cache.DIRECTORY_SEPARATOR.'junit-'.bin2hex(random_bytes(8)).'.xml';
    $junitContainer = CONTAINER_ROOT.'/storage/framework/cache/neotest/'.basename($junitHost);
    $rewritten[] = '--log-junit='.$junitContainer;
}

$projectEnv = envFile($root);
$service = $projectEnv['APP_SERVICE'] ?? getenv('APP_SERVICE') ?: 'laravel.test';
$user = $projectEnv['APP_USER'] ?? getenv('APP_USER') ?: 'sail';
$env = getenv();
$env = is_array($env) ? $env : [];
$env['APP_SERVICE'] = $service;
$env['APP_USER'] = $user;

if ($usesSail && getenv('XDEBUG_TRIGGER') !== false) {
    $command = array_merge([
        $sail, 'exec', '-e', 'XDEBUG_TRIGGER=1', '-u', $user, $service, 'php', './vendor/bin/phpunit',
    ], $rewritten);
} elseif ($usesSail) {
    $command = array_merge([$sail, 'phpunit'], $rewritten);
} else {
    if (!file_exists($localPhpunit)) {
        fwrite(STDERR, "PHPUnit bridge: vendor/bin/phpunit not found\n");
        exit(2);
    }
    $command = array_merge([$localPhpunit], $args);
}

$process = proc_open($command, [
    0 => ['file', 'php://stdin', 'r'],
    1 => ['file', 'php://stdout', 'w'],
    2 => ['file', 'php://stderr', 'w'],
], $pipes, $root, $env);
if (!is_resource($process)) {
    fwrite(STDERR, "PHPUnit bridge: failed to start PHPUnit\n");
    exit(2);
}
$status = proc_close($process);

if ($usesSail && $junitTarget !== null && isset($junitHost) && is_file($junitHost)) {
    $xml = file_get_contents($junitHost);
    if ($xml !== false) {
        file_put_contents($junitTarget, str_replace(CONTAINER_ROOT, $root, $xml));
    }
    unlink($junitHost);
}

exit($status);
