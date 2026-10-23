# 💊 MedSync Flutter

Aplicativo Flutter do **MedSync**, conectado ao backend oficial do projeto.

---

## 🎨 Visual

- 🔵 Identidade visual em azul MedSync (`#2563EB`).
- 🖼️ Logo original reproduzida no app e nos ícones Android.
- 📱 Interface responsiva para celulares e telas largas.
- 🌗 Tema claro e escuro.
- ♿ Modo de acessibilidade com escala de texto ampliada.
- 🔄 Componentes com estados de carregamento, vazio, sucesso e erro.

## ✨ Funcionalidades

- 🔐 Login e cadastro.
- 📊 Dashboard com progresso diário e adesão.
- 💊 Cadastro e edição de medicamentos.
- ⏰ Horários usando seletor de horário nativo.
- ▶️ Ativar ou pausar medicamento.
- 🗑️ Excluir medicamento com confirmação.
- ✅ Registrar dose como tomada.
- 📈 Histórico de registros e métricas de adesão.
- 👤 Edição de perfil.
- 📤 Exportação e compartilhamento dos dados.
- 💾 Persistência de sessão e preferências.

## 🌐 Backend

A API está configurada para:

🔗 **[MedSync API](https://medsync-backend-oqms.onrender.com/api)**

O backend e o banco de dados precisam estar disponíveis para as funcionalidades que dependem da API.

---

## 🚀 Como executar no Windows

### 1. 📂 Abrir o projeto

Abra o Visual Studio Code e clique em **Arquivo → Abrir Pasta**.

Selecione a pasta principal do MedSync, onde está localizado o arquivo `pubspec.yaml`.

### 2. 💻 Abrir o terminal

No menu superior do Visual Studio Code, clique em:

**Terminal → Novo Terminal**

### 3. 🧹 Limpar os arquivos anteriores

No terminal, execute:

```powershell
flutter clean
```

Aguarde a conclusão do comando.

### 4. 📦 Instalar as dependências

Execute:

```powershell
flutter pub get
```

Aguarde até que todas as dependências sejam instaladas.

### 5. 🔎 Analisar o projeto

Execute:

```powershell
flutter analyze
```

Esse comando verifica possíveis problemas no código.

### 6. 🧪 Executar os testes

Execute:

```powershell
flutter test
```

Aguarde a conclusão dos testes automatizados.

### 7. ▶️ Iniciar o aplicativo

Execute:

```powershell
flutter run
```

Pressione **Enter** e aguarde a lista de navegadores aparecer no terminal.

A tela será semelhante a esta:

```text
[1]: Chrome (chrome)
[2]: Edge (edge)
Please choose one (or "q" to quit):
```

### 8. 🌍 Escolher o navegador

Escolha o navegador digitando o número correspondente no terminal:

| Opção | Navegador |
|---|---|
| `1` | Google Chrome |
| `2` | Microsoft Edge |

- Digite **1** e pressione Enter para abrir no Chrome.
- Digite **2** e pressione Enter para abrir no Edge.

**Não é necessário digitar outro comando para escolher o navegador.** Basta informar o número na tela de seleção.

### 9. ✅ Verificar o funcionamento

Quando o aplicativo abrir no navegador, verifique se as telas carregam corretamente e se as funcionalidades estão operando.

Caso apareça algum erro no terminal, copie a mensagem para identificar o problema.

---

## 🤖 Executar no Android

Para executar o projeto em um dispositivo Android ou gerar uma versão para Android, confirme que o Android SDK e os componentes necessários estão instalados.

O projeto solicita a seguinte versão do NDK:

```text
28.2.13676358
```

### 📱 Gerar o APK

Execute:

```powershell
flutter build apk --release
```

Após a compilação, o arquivo APK normalmente estará em:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🛠️ Solução de problemas

### ❌ O comando `flutter` não é reconhecido

Verifique se o Flutter SDK está instalado e configurado na variável de ambiente `PATH`.

### 🌐 Chrome ou Edge não aparecem

Verifique se o navegador está instalado e se o suporte ao Flutter Web está configurado.

Para consultar os dispositivos disponíveis, execute:

```powershell
flutter devices
```

### 🔌 Erro ao conectar com o backend

Verifique:

- Se o computador está conectado à internet.
- Se o endereço da API está correto.
- Se o backend está disponível.
- Se a API está respondendo corretamente.

### 📦 Erro ao instalar dependências

Execute:

```powershell
flutter pub get
```

Depois, tente iniciar novamente:

```powershell
flutter run
```

---

## 📝 Observações

- Execute os comandos na pasta principal do projeto, onde está o arquivo `pubspec.yaml`.
- Para executar no navegador, o projeto precisa estar configurado para Flutter Web.
- Para executar no Android, é necessário configurar o Android SDK e o NDK solicitados pelo projeto.
- A disponibilidade das funcionalidades depende da configuração correta do aplicativo e do backend.

---

**MedSync — Cuidando melhor da sua rotina de medicamentos. 💙**