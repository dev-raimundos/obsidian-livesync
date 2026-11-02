# Obsidian LiveSync no Dokploy

Servidor CouchDB para uso pessoal com o plugin [Self-hosted LiveSync](https://github.com/vrtmrz/obsidian-livesync). Os dados ficam no seu servidor. O plugin deve ser instalado no Obsidian de cada dispositivo; este repositório hospeda o backend, não o aplicativo Obsidian.

## Implantar no Dokploy

1. Envie estes arquivos para seu repositório Git, incluindo a pasta `.docker`. Não envie `.env`.
2. No Dokploy, crie um projeto e um serviço **Docker Compose**, conecte o repositório e escolha **Compose**, não Docker Stack. Informe `compose.yaml` como caminho do Compose e a raiz do repositório como contexto.
3. Na seção **Environment**, copie `.env.example`, defina `COUCHDB_USER` e uma senha forte em `COUCHDB_PASSWORD`. Escolha o banco em `COUCHDB_DATABASE` (padrão `obsidiannotes`). Não deixe a senha vazia. Para evitar interpolação de `$` no Compose, prefira uma senha aleatória hexadecimal (por exemplo, `openssl rand -hex 32`).
4. Em **Domains**, adicione seu domínio, por exemplo `sync.seudominio.com`, selecione o serviço **couchdb**, porta interna **5984**, caminho `/`, HTTPS e certificado Let's Encrypt. Aponte o DNS ao servidor e permita as portas 80/443. O Dokploy gera as configurações do Traefik automaticamente; não há outro proxy nesta stack.
5. Faça o deploy. O `couchdb` deve ficar saudável e o `couchdb-init` deve terminar com código **0**. O término do init é esperado. Confira os logs de ambos.

O build usa `couchdb:3.5.1`, copia a configuração para a imagem e não depende de bind mounts do checkout. A autenticação e o CORS estão ativos desde o início. O init cria os bancos internos e o banco do vault, aceitando bancos já existentes sem sobrescrever documentos. Os metadados do LiveSync são inicializados pelo plugin na configuração do primeiro dispositivo.

### Porta publicada

O Dockerfile expõe **5984** e o Compose publica **5984:5984** por padrão. `COUCHDB_PORT` altera somente a porta no host; o domínio do Dokploy continua apontando à porta interna 5984.

O mapeamento padrão usa `0.0.0.0` e oferece HTTP direto. Para acessar somente por HTTPS pelo Dokploy, defina `COUCHDB_BIND_ADDRESS=127.0.0.1` antes do deploy. O Traefik acessa o serviço pela rede Docker. Para HTTP na rede local, mantenha `0.0.0.0` e restrinja o acesso à porta no servidor. Não use HTTP direto pela Internet para transmitir suas credenciais. Dispositivos móveis precisam de HTTPS com certificado válido.

## Configurar o Obsidian

Faça backup do vault antes de começar e desative outras ferramentas de sincronização nesse mesmo vault.

1. Instale e habilite o plugin comunitário **Self-hosted LiveSync**.
2. Use o assistente de configuração manual de CouchDB no primeiro dispositivo:

   | Campo | Valor |
   | --- | --- |
   | URI do servidor | `https://sync.seudominio.com` (sem `:5984` e sem o banco no caminho) |
   | Usuário | `COUCHDB_USER` |
   | Senha | `COUCHDB_PASSWORD` |
   | Banco | `COUCHDB_DATABASE`, por padrão `obsidiannotes` |

3. Execute a verificação de configuração do servidor no plugin. Ative a criptografia ponta a ponta e escolha uma frase secreta própria; ela não é configurada neste servidor.
4. Escolha o modo de sincronização desejado e faça a primeira sincronização. Depois, gere uma **Setup URI** pelo plugin para configurar os demais dispositivos com as mesmas opções. Guarde a frase secreta e as informações de recuperação.

Este projeto usa uma conta administradora para o uso pessoal, como a configuração básica do upstream. A senha permite administrar todo o CouchDB. Não compartilhe essa conta com terceiros.

## Executar localmente

Copie `.env.example` para `.env` e preencha a senha. O `.env` local gerado durante a preparação já contém uma senha aleatória e está ignorado pelo Git.

```sh
docker compose config --quiet
docker compose up -d --build
docker compose ps -a
docker compose logs couchdb-init
```

Teste com seu usuário; o curl solicitará a senha:

```sh
curl --fail --user livesync_admin http://localhost:5984/_up
curl --fail --user livesync_admin http://localhost:5984/obsidiannotes
curl -i --user livesync_admin -H 'Origin: app://obsidian.md' http://localhost:5984/obsidiannotes
curl -i http://localhost:5984/obsidiannotes
```

Espere `{"status":"ok"}`, informações do banco, cabeçalhos CORS permitindo a origem e **401** na última chamada sem autenticação. Repita com seu domínio HTTPS após o deploy. `/_up` pode ser público; use o banco para verificar a autenticação.

## Persistência e manutenção

Os bancos ficam no volume nomeado `couchdb-data`, com prefixo do projeto Compose gerenciado pelo Dokploy. Redeploys preservam o volume. Mantenha a identidade do projeto e o volume; **`docker compose down -v` apaga os dados**. A pasta local `data/` não é usada.

Configure backups do volume no Dokploy, com o CouchDB parado para uma cópia consistente, ou use replicação de backup conforme a documentação do CouchDB. Guarde também este repositório, as credenciais e as frases secretas do plugin. Teste a restauração antes de depender do backup.

Para atualizar o CouchDB, altere a versão no Dockerfile após conferir as notas de versão e fazer backup; faça novo deploy com build. Mudanças de configuração na imagem exigem recriar o container. Se modificar configurações pela API/Fauxton, registre-as também no arquivo `.docker/livesync.ini`, pois somente os bancos são persistidos.

Para executar novamente a criação dos bancos sem apagar dados:

```sh
docker compose run --rm couchdb-init
```

Nomes de banco devem começar com letra minúscula e usar letras minúsculas, números ou `_ $ ( ) + -`. Alterar o nome cria outro banco; não migra o vault antigo. Se a porta 5984 estiver ocupada, altere `COUCHDB_PORT`. Em erros de inicialização, consulte os logs; não remova o volume como tentativa de reparo.

## Referências

- [Projeto original](https://github.com/vrtmrz/obsidian-livesync)
- [Stack Docker oficial](https://github.com/vrtmrz/obsidian-livesync/blob/main/docker/README.md)
- [Servidor próprio e configuração manual](https://github.com/vrtmrz/obsidian-livesync/blob/main/docs/setup_own_server.md)
- [Domínios de Docker Compose no Dokploy](https://docs.dokploy.com/docs/core/docker-compose/domains)
- [Backup do CouchDB](https://docs.couchdb.org/en/stable/maintenance/backups.html)

Configuração baseada nas orientações do projeto original, distribuído sob licença MIT; o aviso upstream está em `LICENSE`.
