# 🎮 Easy RO Docker

Bem-vindo ao **Easy RO Docker**, um ambiente completo e containerizado para servidor de Ragnarok Online com Docker. Este setup inclui:

- 🐋 MariaDB para armazenar dados do jogo  
- ⚙️ Servidor rAthena (em C++)  
- 🕹️ Painel de controle web FluxCP  
- 🧪 phpMyAdmin para acesso fácil ao banco de dados

> 🛠️ **Reestruturado e adaptado para ARM64**: Este projeto foi repensado a partir do [repositório original](https://github.com/deckyfx/ragnarok-online) de deckyfx, com foco em compatibilidade total para arquiteturas ARM64 — como processadores **Ampere Altra**, amplamente utilizados em **VMs da Oracle Cloud**, além de **Raspberry Pi 4/5** e **Apple M1/M2**.

---

## 🖼️ Prévia

![Screenshot do FluxCP](assets/screenshoot01.jpg)

---

## 🚀 Primeiros Passos

### 1. 📦 Instale o Docker

Garanta que você está usando a **versão mais recente do Docker** e do Docker Compose:

- [Instalar Docker](https://docs.docker.com/get-docker/)
- [Instalar Docker Compose](https://docs.docker.com/compose/install/)

---

### 2. 🔁 Clone este repositório

```bash
git clone https://github.com/MrFerbic/ragnarok-online.git
cd ragnarok-online
```

---

### 3. 🛠️ Construa as Imagens Docker

```bash
docker build -t rathena:0.0.1 ./rathena
docker build -t fluxcp:0.0.1 ./fluxcp
```

---

### 4. ⚙️ Configure o ambiente

Copie o arquivo `.env.example` e ajuste com seus dados:

```bash
cp .env.example .env
nano .env
```

Certifique-se de configurar seu IP público/local, senhas do banco de dados, rates e `packetver`.

---

### 5. 🧬 Suba o servidor

```bash
docker compose up
```

Seu servidor estará rodando com:

- 🧠 rAthena nas portas **5121, 6121, 6900**
- 🌐 FluxCP: http://localhost:5123
- 🧪 phpMyAdmin: http://localhost:5124

---

## 🧹 Manutenção

Parar e remover os containers:

```bash
docker compose down
```

Reconstruir imagens após mudanças:

```bash
docker compose build --no-cache
```

---

## 📁 Estrutura de Pastas

```text
ragnarok-online/
├── rathena/             # Código e imagem personalizada do rAthena
├── fluxcp/              # Código e imagem do painel FluxCP
├── mariadb/             # Volume de dados do MySQL
├── .env                 # Configurações de ambiente
├── docker-compose.yml   # Orquestração com Docker
└── README.md
```

---

## 🧩 Configurar o Cliente RO

1. Baixe o client em inglês atualizado do repositório [ROClient_en](https://github.com/hiphop9/ROClient_en)

2. Baixe o **Full Client** (~3.9 GB) e o executável já **patchado**

3. Extraia o client e substitua o `.exe` pelo executável patchado

4. Edite o arquivo `data/clientinfo.xml` do client para apontar para seu IP/porta:

```xml
<?xml version="1.0" encoding="euc-kr" ?>
<clientinfo>
  <desc>Ragnarok Client Information</desc>
  <servicetype>korea</servicetype>
  <servertype>primary</servertype>
  <connection>
    <display>Servidor Local</display>
    <address>192.168.0.102</address>
    <port>6900</port>
    <version>55</version>
    <langtype>1</langtype>
    <registrationweb>http://192.168.0.102:5023</registrationweb>
    <loading>
      <image>loading00.jpg</image>
      <image>loading01.jpg</image>
      <image>loading02.jpg</image>
      <image>loading03.jpg</image>
      <image>loading04.jpg</image>
      <image>loading05.jpg</image>
      <image>loading06.jpg</image>
    </loading>
    <aid>
      <admin>1</admin>
      <admin>2000000</admin>
    </aid>
  </connection>
</clientinfo>
```

---

## 🔐 Criar Conta Admin

Após a instalação, crie uma conta admin executando este SQL pelo phpMyAdmin:

```sql
INSERT INTO `login` (`account_id`, `userid`, `user_pass`, `sex`, `email`, `group_id`, `state`, `unban_time`, `expiration_time`, `logincount`, `lastlogin`, `last_ip`, `birthdate`, `character_slots`, `pincode`, `pincode_change`, `vip_time`, `old_group`, `web_auth_token`, `web_auth_token_enabled`)
VALUES (2000000, 'admin', 'admin123', 'F', 'admin@athena.com', 99, 0, 0, 0, 5, NOW(), '192.168.0.100', NULL, 0, '1412', 1747530571, 0, 0, 'ce6a6fa2899bbf24', 0);
```

---

## 🙏 Créditos

- [rAthena](https://github.com/rathena/rathena)
- [FluxCP](https://github.com/rathena/FluxCP)
- [phpMyAdmin](https://www.phpmyadmin.net/)
- [Docker](https://www.docker.com/)
- [deckyfx/ragnarok-online](https://github.com/deckyfx/ragnarok-online)

---

## 📌 Observações

Este projeto pode ser estendido com:

- Script de instalação automática do banco para o FluxCP  
- Suporte a múltiplas línguas  
- Deploy em serviços como Oracle Cloud, AWS Graviton, Raspberry Pi etc.

---

Feito com ❤️ no Brasil por [MrFerbic](https://github.com/MrFerbic)
