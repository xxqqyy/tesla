param(
    [string]$MySqlRootPassword = "tesla-local-dev"
)

$ErrorActionPreference = "Stop"

function Ensure-Container {
    param(
        [string]$Name,
        [string[]]$RunArguments
    )

    & docker container inspect $Name *> $null
    if ($LASTEXITCODE -ne 0) {
        & docker run -d --name $Name @RunArguments
        if ($LASTEXITCODE -ne 0) { throw "Failed to create Docker container: $Name" }
        return
    }

    $running = & docker inspect -f '{{.State.Running}}' $Name
    if ($running -ne "true") {
        & docker start $Name
        if ($LASTEXITCODE -ne 0) { throw "Failed to start Docker container: $Name" }
    }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$schemaPath = Join-Path $projectRoot "tesla-server\database.sql"
$schemaMount = "{0}:/docker-entrypoint-initdb.d/01-schema.sql:ro" -f $schemaPath

Ensure-Container -Name "tesla-local-mysql" -RunArguments @(
    "--restart", "unless-stopped",
    "-p", "127.0.0.1:3306:3306",
    "-e", "MYSQL_ROOT_PASSWORD=$MySqlRootPassword",
    "-e", "MYSQL_DATABASE=teslaapp",
    "-v", "tesla-local-mysql-data:/var/lib/mysql",
    "-v", $schemaMount,
    "mysql:8.4"
)

Ensure-Container -Name "tesla-local-redis" -RunArguments @(
    "--restart", "unless-stopped",
    "-p", "127.0.0.1:6379:6379",
    "-v", "tesla-local-redis-data:/data",
    "redis:7-alpine", "redis-server", "--appendonly", "yes"
)

Write-Host "Waiting for MySQL and Redis to become ready..."
for ($attempt = 1; $attempt -le 30; $attempt++) {
    $mysqlReady = (& docker exec tesla-local-mysql mysqladmin ping -h 127.0.0.1 --silent) -eq "mysqld is alive"
    $redisReady = (& docker exec tesla-local-redis redis-cli ping) -eq "PONG"
    if ($mysqlReady -and $redisReady) {
        Write-Host "Dependencies are ready."
        exit 0
    }
    Start-Sleep -Seconds 2
}

throw "MySQL or Redis did not become ready within 60 seconds. Run 'docker logs tesla-local-mysql' or 'docker logs tesla-local-redis'."
