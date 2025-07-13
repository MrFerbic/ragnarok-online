# FluxCP Docker

Este repositório contém os arquivos para criar a imagem Docker do **FluxCP** — o painel web de administração para servidores rAthena Ragnarok Online.

---

## 🐋 Sobre

Esta imagem Docker automatiza a instalação e configuração do FluxCP dentro de um container baseado em PHP Apache. Ela:

- Clona o repositório oficial do FluxCP (configurável via variável de ambiente).
- Faz checkout da branch e commit desejados.
- Ajusta automaticamente as configurações de banco de dados e host pelo `.env`.
- Executa o Apache para servir o painel.

---

## 📦 Conteúdo

- `Dockerfile`: Define a imagem PHP com Apache e as dependências necessárias.
- `docker-entrypoint.sh`: Script de inicialização para configurar o FluxCP.
- `readme.txt`: Este arquivo de documentação (recomendo migrar para `README.md`).

---

## 🚀 Como usar

1. Clone este repositório junto com o resto do seu projeto.

2. Ajuste as variáveis de ambiente no seu `.env` para apontar para seu banco e configurar o FluxCP.

3. Construa a imagem:
   
   ```bash
   docker build -t fluxcp:0.0.1 .
   ```

4. Execute o container (exemplo com `docker-compose`):
   
   ```bash
   docker compose up fluxcp
   ```

5. Acesse o painel FluxCP via browser no IP e porta configurados (`http://localhost:5123` ou conforme seu `.env`).

---

## 🔧 Variáveis de ambiente importantes

| Variável                    | Descrição                                        | Padrão                                  |
| --------------------------- | ------------------------------------------------ | --------------------------------------- |
| `FLUXCP_REPO_URL`           | URL do repositório Git do FluxCP                 | `https://github.com/rathena/FluxCP.git` |
| `FLUXCP_BRANCH`             | Branch Git a ser usada                           | `master`                                |
| `FLUXCP_COMMIT`             | Commit Git específico (opcional)                 | *nenhum*                                |
| `FLUXCP_HOST`               | IP ou hostname do servidor FluxCP (configuração) | *nenhum* (deve ser configurado)         |
| `FLUXCP_INSTALLER_PASSWORD` | Senha para o instalador FluxCP                   | *nenhum* (deve ser configurado)         |
| `MYSQL_HOST`                | Host do banco MariaDB                            | `db`                                    |
| `MYSQL_DB`                  | Nome do banco MariaDB                            | `ragnarok`                              |
| `MYSQL_USER`                | Usuário do banco                                 | `ragnarok`                              |
| `MYSQL_PWD`                 | Senha do usuário do banco                        | `ragnarok`                              |

---

## 🛠️ Personalização

Você pode personalizar a instalação, especificando diferentes branches, commits ou alterando as configurações diretamente pelo `.env`.

Lembre-se de manter a persistência dos dados do banco em volumes Docker externos.

---

## ⚠️ Avisos

* As permissões dos arquivos são ajustadas para o usuário `www-data` automaticamente.
* Este container espera que o banco de dados MariaDB esteja acessível na rede Docker.
* Sempre proteja seu painel com senhas seguras, especialmente em ambientes de produção.

---

## 📜 Licença e Créditos

Baseado no repositório oficial [FluxCP](https://github.com/rathena/FluxCP).
Adaptado para Docker e ARM64 por [MrFerbic](https://github.com/MrFerbic).

---

Se precisar de ajuda ou quiser contribuir, fique à vontade para abrir issues ou pull requests!

---
