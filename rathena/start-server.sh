#!/bin/bash

# Diretório base do rAthena, pode ser sobrescrito pela variável ambiente RATHENA_DIR
RATHENA_DIR=${RATHENA_DIR:-/rAthena}

# Diretório onde os logs serão armazenados
LOG_DIR="${RATHENA_DIR}/logs"

# Data atual no formato YYYY-MM-DD para rotacionar os logs por dia
DATE=$(date +%F)

# Cria o diretório de logs caso não exista
mkdir -p "$LOG_DIR"

echo "📜 Starting rAthena servers with daily log rotation..."

# Inicia o char-server e redireciona stdout e stderr para arquivo de log
"$RATHENA_DIR"/char-server > "$LOG_DIR/char-${DATE}.log" 2>&1 &
echo "🧑 char-server started (log: $LOG_DIR/char-${DATE}.log)"

# Inicia o login-server e redireciona saída para log
"$RATHENA_DIR"/login-server > "$LOG_DIR/login-${DATE}.log" 2>&1 &
echo "🔐 login-server started (log: $LOG_DIR/login-${DATE}.log)"

# Inicia o map-server e redireciona saída para log
"$RATHENA_DIR"/map-server > "$LOG_DIR/map-${DATE}.log" 2>&1 &
echo "🗺️ map-server started (log: $LOG_DIR/map-${DATE}.log)"

# Inicia o web-server e redireciona saída para log
"$RATHENA_DIR"/web-server > "$LOG_DIR/web-${DATE}.log" 2>&1 &
echo "🗺️ web-server started (log: $LOG_DIR/web-${DATE}.log)"

# Aguarda os processos filhos terminarem (isso fará o script "esperar" enquanto os servidores rodarem)
wait
