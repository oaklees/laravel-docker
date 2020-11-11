#!/usr/bin/env sh

set -e

ROLE=${CONTAINER_ROLE:-app}
ENVIRONMENT=${APP_ENV:-local}
ARTISAN="/var/www/artisan"

##############################
##   Function Definitions   ##
##############################

_verify_artisan_is_present() {
  if [ ! -e $ARTISAN ]; then
    echo "Artisan not found."
    exit 1
  fi
}

_print_role_and_environment() {
  echo "Running as $ROLE in $ENVIRONMENT"
}

_register_trap() {
  trap _did_receive_sigterm SIGTERM
}

_enable_development_extensions_if_required() {
  if [ ! -z "${XDEBUG_ENABLED:-}" ] && [ "$XDEBUG_ENABLED" = "1" ] ; then
    sed -i "s/;zend_extension=.*/zend_extension=xdebug.so/g" /etc/php7/conf.d/00_xdebug.ini
  fi
}

_validate_role() {

  for VALID_ROLE in "app" "queue" "queue.database" "scheduler"; do
    if [ $ROLE = "$VALID_ROLE" ]; then
      return 0
    fi
  done

  echo "Invalid role definition"
  exit 1
}

_prepare_app_for_production() {
  if [ $ENVIRONMENT = production* ]; then
      echo "Caching for production.."
      php ${ARTISAN} config:cache
      php ${ARTISAN} view:cache
      php ${ARTISAN} route:cache || echo 'Route caching not possible.'
  fi
}

_run_database_migration() {

  if [ -n "$SKIP_MIGRATIONS" ]; then
    echo "Skipping migrations."
    return
  fi

  if [ -z "$DB_HOST" ]; then
    echo "Skipping migrations as DB_HOST not defined."
    return
  fi

  echo "Running migrations.."

  _wait_for_database_to_be_available

  c=0
  i=1

  while ! (php ${ARTISAN} migrate --force); do
      c=`expr $c + $i` && [ $c == 6 ] && c=0 && echo "Failed to run migrations" && break
      echo "Migrations unsuccessful, waiting for retry.. ($c of 5)"
      sleep 1
  done
}

_wait_for_database_to_be_available() {
  if [ "$DB_CONNECTION" = "mysql" ] && [ -n $DB_HOST ]; then
      wait-for-it.sh -t 60 "$DB_HOST:$DB_PORT"
  fi
}

_did_receive_sigterm() {

  if [ -n "$SUPERVISOR_PID" ]; then
    _stop_supervisor
  fi

  if [ -n "$HORIZON_PID" ]; then
    _stop_horizon
  fi

  if [ -n "$DATABASE_WORKER_PID" ]; then
    _stop_database_worker
  fi

  if [ "$ROLE" = "scheduler" ]; then
    _stop_scheduler
  fi

  exit 0
}

_start_supervisor() {
  /usr/bin/supervisord -c /etc/supervisor/supervisord.conf &
  SUPERVISOR_PID=$!
}

_stop_supervisor () {
  echo "Sending SIGTERM to Supervisor"
  kill -SIGTERM "$SUPERVISOR_PID"
  # Wait for the Supervisor process to exit
  wait "$SUPERVISOR_PID"
  echo "Supervisor exited"
}

_start_horizon() {
  php ${ARTISAN} horizon &
  HORIZON_PID=$!
}

_start_database_queue_worker() {
  php ${ARTISAN} queue:work database &
  DATABASE_WORKER_PID=$!
}

_stop_horizon () {
  echo "Sending SIGINT to Horizon"
  kill -SIGINT "$HORIZON_PID"
  # Wait for the Horizon process to exit
  wait "$HORIZON_PID"
  echo "Horizon exited"
}

_stop_database_worker () {
  echo "Sending SIGTERM to database worker"
  kill -SIGTERM "$DATABASE_WORKER_PID"
  # Wait for the Database worker process to exit
  wait "$DATABASE_WORKER_PID"
  echo "Database worker exited"
}

_wait_on_active_processes() {
  if [ -n "$SUPERVISOR_PID" ]; then
    wait $SUPERVISOR_PID
  fi
  if [ -n "$DATABASE_WORKER_PID" ]; then
    wait $DATABASE_WORKER_PID
  fi
  if [ -n "$DATABASE_WORKER_PID" ]; then
    wait $DATABASE_WORKER_PID
  fi
}

_start_scheduler() {
  while true
  do
    php ${ARTISAN} schedule:run --verbose --no-interaction &
    SCHEDULER_PID=$!
    (sleep 60) &
    SCHEDULER_WAIT_PID=$!
    wait "$SCHEDULER_WAIT_PID"
  done
}

_stop_scheduler() {

  echo "SIGTERM received for Scheduler"

  if kill -0 "$SCHEDULER_PID" > /dev/null 2>&1; then
      echo "Waiting for scheduled task to complete.."
      wait "$SCHEDULER_PID"
  fi

  echo "Sending SIGTERM to Scheduler"
  kill "$SCHEDULER_WAIT_PID"
}

####################
##   Entrypoint   ##
####################

_verify_artisan_is_present
_enable_development_extensions_if_required
_print_role_and_environment
_register_trap
_validate_role

if [ "$ROLE" = "scheduler" ]; then
  _start_scheduler
fi

_prepare_app_for_production

if [ "$ROLE" = "app" ]; then
  _run_database_migration
fi

if [ "$ROLE" = "queue" ]; then
  _start_horizon
fi

if [ "$ROLE" = "queue.database" ]; then
  _start_database_queue_worker
fi

_start_supervisor
_wait_on_active_processes





