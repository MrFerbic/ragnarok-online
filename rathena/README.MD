# rAthena - Servidor Ragnarok Online

Este projeto contém a configuração e scripts para rodar um servidor rAthena usando Docker.

---

## Estrutura dos arquivos

- **Dockerfile**  
  Define a imagem Docker baseada em Debian 11, instala dependências essenciais, copia os scripts e configurações, expõe as portas padrão do servidor e define o entrypoint.

- **docker-entrypoint.sh**  
  Script principal que:
  - Espera o banco de dados MySQL ficar disponível;
  - Clona o repositório rAthena se necessário;
  - Compila o servidor;
  - Configura os arquivos de configuração baseados nas variáveis de ambiente;
  - Inicializa a base de dados importando arquivos SQL padrão e personalizados;
  - Configura taxas, NPCs customizados e outras opções do servidor;
  - Por fim, executa o comando passado para iniciar o servidor.

- **start-server.sh**  
  Script para iniciar os servidores `char-server`, `login-server`, `map-server` e `web-server`, criando logs diários separados na pasta `logs`.

- **accountsandchars.sql**  
  SQL para criação inicial de contas e personagens, incluindo GMs e bots.

- **firstaccount.sql**  
  SQL para configurar a primeira conta de sistema, necessária para funcionamento correto.

- **gab_npc.txt**  
  Script NPC customizado que adiciona um NPC para spawn de monstros em `gef_fild07` e pontos de cura em cidades principais.

- **readme.txt**  
  Arquivo de descrição simples do projeto (a ser criado).

---

## Variáveis de ambiente importantes

- `MYSQL_HOST` - Host do banco de dados MySQL
- `MYSQL_DB` - Nome do banco de dados a ser usado
- `MYSQL_USER` - Usuário do banco
- `MYSQL_PWD` - Senha do usuário
- `RATHENA_REPO_URL` - URL do repositório rAthena (padrão: oficial no GitHub)
- `RATHENA_BRANCH` - Branch para checkout (padrão: master)
- `RATHENA_COMMIT` - Commit específico opcional para checkout
- `HOST_UID` e `HOST_GID` - Para ajustar permissões dos arquivos gerados
- Variáveis de configuração do servidor (taxas, IPs, start items, etc) definidas conforme padrão no `docker-entrypoint.sh`

---

## Como usar

1. Configure as variáveis de ambiente adequadamente.
2. Construa a imagem Docker a partir deste diretório:

   ```bash
   docker build -t rathena-server .
```

3. Execute o container, conectando ao banco MySQL e mapeando as portas necessárias:

   ```bash
   docker run -d \
     -e MYSQL_HOST=seu_host_mysql \
     -e MYSQL_DB=rathena_db \
     -e MYSQL_USER=usuario \
     -e MYSQL_PWD=senha \
     -p 6900:6900 -p 6121:6121 -p 5121:5121 \
     rathena-server
   ```

4. Os logs estarão disponíveis na pasta `/rAthena/logs` dentro do container.

---

## Notas adicionais

* O script `docker-entrypoint.sh` faz toda a preparação, incluindo clonagem e build do rAthena.
* O script `start-server.sh` é o comando padrão para iniciar todos os servidores de jogo.
* Os arquivos SQL são importados automaticamente se a base ainda não existir.
* Personalize os NPCs e configurações conforme sua necessidade alterando os arquivos em `/rAthena`.
