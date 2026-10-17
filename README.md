# FileMind — Organizador Inteligente de Arquivos

Organizador inteligente e renomeador de arquivos em Python. Monitora uma pasta com **watchdog**, extrai texto e metadados localmente e usa **Groq + Llama 3.3** para sugerir categoria, subcategoria e nome descritivo. A extensão original é sempre controlada pelo Python.

```text
Downloads/NF_938492_download.PDF
    ↓ extração → classificação → validação
Organizados/Financeiro/NotasFiscais/2026-10-16_NotaFiscal_LojaExemplo.PDF
```

O nome acima é ilustrativo: a sugestão depende do conteúdo. Sem data explícita, o prefixo é `SemData`; baixa confiança direciona para `Outros/Revisar`. Uma estimativa de confiança do modelo não é uma probabilidade calibrada.

## Recursos

- Monitora criação, modificação e renomeação na raiz da pasta, em uma fila com um único consumidor.
- PDF com pypdf, TXT com detecção básica de codificação, DOCX com parágrafos e tabelas.
- PNG, JPG, JPEG, WEBP, TIF, TIFF e BMP por metadados; OCR local opcional com Tesseract.
- JSON validado por Pydantic: tipos estritos, campos extras proibidos, datas reais e taxonomia controlada.
- Sanitização de nomes compatível com Windows, Linux e macOS.
- Preserva extensão exatamente: `.PDF` continua `.PDF`, `.JpEg` continua `.JpEg`.
- Colisões recebem `_001`, `_002` etc.; criação exclusiva impede sobrescrever um destino existente.
- Simulação por padrão; cópia por padrão quando `--apply` é informado.
- Movimento opcional: copia, sincroniza e compara SHA-256 antes de apagar a origem.
- SQLite guarda histórico mínimo para evitar reprocessamento da mesma origem/conteúdo já organizado.
- CI para Linux e Windows, Python 3.11, 3.12 e 3.13; testes usam mocks e não consomem API.

## Estrutura

```text
smart-file-organizer/
├── main.py                      # Script principal completo e comentado
├── requirements.txt             # Dependências de execução
├── requirements-dev.txt         # Testes e lint
├── pyproject.toml               # Configuração das ferramentas
├── .env.example                 # Exemplo sem credencial real
├── .gitignore
├── .github/workflows/ci.yml
├── examples/nota_fiscal.txt      # Documento fictício
├── tests/test_main.py
└── README.md
```

## Requisitos e instalação

Python 3.11 ou superior. Não é necessário GPU. Crie uma chave na [Groq Console](https://console.groq.com/keys). O serviço oferece um plano gratuito com limites; modelos, cotas e disponibilidade podem mudar. Este projeto não promete uso ilimitado ou gratuidade permanente.

No terminal, dentro desta pasta:

```bash
python -m venv .venv
```

Windows PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
Copy-Item .env.example .env
```

Linux/macOS:

```bash
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
cp .env.example .env
```

Preencha `.env` localmente:

```dotenv
GROQ_API_KEY=sua_chave_da_groq
GROQ_MODEL=llama-3.3-70b-versatile
```

Não envie sua chave ao GitHub. `.env` é ignorado pelo Git; `.env.example` contém apenas um marcador.

## Experimento rápido

Crie `entrada-teste`, copie o documento fictício e simule:

```bash
mkdir entrada-teste
```

PowerShell: `Copy-Item examples/nota_fiscal.txt entrada-teste/`.
Linux/macOS: `cp examples/nota_fiscal.txt entrada-teste/`.

```bash
python main.py --watch ./entrada-teste --output ./saida-teste --once
```

A simulação **ainda chama a Groq e envia o texto extraído**, mas não copia, move nem renomeia documentos. Ela cria o arquivo de estado SQLite, sem registrar a classificação como aplicada.

Para efetivar a cópia:

```bash
python main.py --watch ./entrada-teste --output ./saida-teste --once --apply
```

Para monitorar continuamente Downloads e organizar por cópia:

```bash
python main.py --watch "C:/Users/SEU_USUARIO/Downloads" --output "C:/Users/SEU_USUARIO/Organizados" --apply
```

Para **mover** os arquivos novos e incluir os existentes:

```bash
python main.py --watch ~/Downloads --output ~/Organizados --scan-existing --apply --mode move
```

No Windows substitua os caminhos pelos seus. Use `Ctrl+C` para parar. A operação já iniciada termina antes de fechar. Sem `--scan-existing`, apenas eventos novos são processados. O monitoramento não é recursivo e não altera subpastas já existentes.

## Llama 3 e schema JSON estrito

Há duas garantias diferentes:

| Modo | Modelo de exemplo | Garantia |
|---|---|---|
| Padrão | `llama-3.3-70b-versatile` | Groq `json_object` + validação estrita local com Pydantic; até 3 tentativas de resposta válida |
| `--strict-server` | `openai/gpt-oss-20b` | Groq `json_schema`, `strict: true`, mais a mesma validação local |

Llama 3.3 não é tratado aqui como modelo com constrained decoding para schema. Nenhuma resposta inválida chega à operação de arquivos. Não há fallback silencioso entre modelos.

Para solicitar schema estrito também no servidor:

```bash
python main.py --watch ./entrada-teste --output ./saida-teste --once --strict-server --model openai/gpt-oss-20b
```

Consulte os modelos suportados na documentação da Groq antes de mudar o modelo. Se incompatível, a chamada falha e o documento permanece na origem.

Contrato de exemplo:

```json
{
  "category": "Financeiro",
  "subcategory": "NotasFiscais",
  "title": "NotaFiscal_LojaExemplo",
  "document_date": "2026-10-16",
  "confidence": 0.95
}
```

Todos os campos são obrigatórios; `document_date` aceita `null`. A IA não fornece extensão ou caminho de destino. Categoria e subcategoria são verificadas contra os pares de `TAXONOMY` no início de `main.py`.

## Categorias

| Categoria | Subcategorias |
|---|---|
| Financeiro | NotasFiscais, Boletos, Comprovantes, Outros |
| Estudos | Apostilas, Exercicios, Certificados, Outros |
| Trabalho | Contratos, Curriculos, Relatorios, Outros |
| Pessoal | Documentos, Saude, Outros |
| Midia | Fotografias, CapturasDeTela, Outros |
| Outros | Revisar |

Edite `TAXONOMY` para adaptar a classificação. O prompt e a validação usam a mesma configuração, evitando divergência entre instruções e pastas permitidas.

## OCR de imagens

Sem OCR, imagens são analisadas apenas pelo nome e por metadados de formato, dimensões e data EXIF. Não há reconhecimento visual de cenas; o Llama recebe texto, não pixels.

Instale [Tesseract OCR](https://tesseract-ocr.github.io/tessdoc/Installation.html), os idiomas português e inglês e adicione o executável ao `PATH`. Instale também o adaptador Python:

```bash
python -m pip install 'pytesseract>=0.3.13,<0.4'
python main.py --watch ./entrada-teste --output ./saida-teste --once --ocr --ocr-lang por+eng
```

PDF escaneado **não recebe OCR automático nesta versão**: pypdf não faz OCR. Pode ser classificado por seus metadados e deve ser revisado. Para extrair seu texto, primeiro gere uma versão pesquisável com uma ferramenta de OCR. DOCX com imagens embutidas também não recebe OCR.

## Configuração da CLI

| Opção | Padrão | Finalidade |
|---|---|---|
| `--watch` | `~/Downloads` | Pasta existente monitorada |
| `--output` | `~/Organizados` | Raiz de destino |
| `--state` | `~/.smart-file-organizer/state.sqlite3` | Histórico de origem, hash, destino e horário |
| `--apply` | desativado | Autoriza operações sobre documentos |
| `--mode` | `copy` | `copy` ou `move` |
| `--once` | desativado | Varre arquivos atuais e termina |
| `--scan-existing` | desativado | Varre existentes ao iniciar monitoramento |
| `--model` | `.env` ou Llama 3.3 | Modelo da Groq |
| `--strict-server` | desativado | Exige suporte a `json_schema` estrito |
| `--ocr` | desativado | OCR local em imagens |
| `--ocr-lang` | `por+eng` | Idiomas Tesseract |
| `--threshold` | `0.75` | Confiança mínima para não ir a Revisar |
| `--max-mb` | `30` | Limite de tamanho por arquivo |
| `--max-chars` | `12000` | Limite de texto enviado |
| `--pdf-pages` | `8` | Máximo de páginas iniciais analisadas |
| `--ready-timeout` | `120` | Segundos esperando estabilidade |

O limite de texto não é limite de tokens; nomes e metadados também entram no prompt. Ajuste para sua cota. O SDK faz até duas novas tentativas de erros transitórios, além das tentativas de validação da aplicação. Falhas finais deixam o documento para reprocessamento manual.

## Integridade, privacidade e limites

- O conteúdo textual extraído, nome e metadados selecionados são enviados à Groq. Não use documentos sensíveis sem avaliar esse envio e as políticas do provedor. Os binários não são enviados.
- O log inclui nomes e destinos, mas não texto extraído, chave ou resposta bruta. O SQLite também contém caminhos; proteja o diretório de estado.
- A origem é removida no modo `move` somente após cópia sincronizada e hash verificado. Faça sua primeira execução em uma pasta de teste e mantenha backup de documentos importantes.
- Esperar estabilidade reduz erros com downloads incompletos; uma pausa longa no download pode parecer conclusão. Extensões temporárias como `.crdownload`, `.part` e `.tmp` são ignoradas. Reprocessar com `--once` recupera pendências.
- O destino é criado exclusivamente; interrupção abrupta do processo ou falta de energia pode deixar cópia parcial. A origem permanece até a verificação finalizar. Não há transação atômica entre filesystem e SQLite: uma interrupção após copiar pode gerar duplicata em nova execução.
- Execute uma única instância por pasta. A aplicação não é uma sandbox contra alterações maliciosas concorrentes de caminhos. Links simbólicos de origem são rejeitados e a raiz resolvida do destino é verificada, mas operações de filesystem não são uma transação contra outros processos.
- A fila comporta 2.000 arquivos. Eventos duplicados pendentes são agrupados. Sob sobrecarga ou quando um arquivo muda durante a análise, rode `--once` depois que a pasta estabilizar. Eventos do sistema operacional não são uma fila durável.
- O cache identifica **caminho de origem + SHA-256**, não elimina cópias iguais em caminhos diferentes. Uma cópia aplicada e registrada é ignorada enquanto o destino existir com o hash esperado. Para reclassificar deliberadamente, use um novo `--state`.
- PDFs corrompidos ou criptografados, arquivos vazios e formatos não suportados não são movidos. PDFs muito complexos ainda podem consumir memória/CPU na extração: limites de tamanho/páginas não substituem isolamento para arquivos hostis.
- IA pode errar mesmo com schema válido. O diretório Revisar reduz ações com baixa confiança, mas não elimina revisão humana.
- `pypdf` limita a análise às páginas iniciais configuradas; o título pode refletir somente esse trecho. Preservar extensão não valida se o binário é realmente daquele formato.

## Testes e qualidade

```bash
python -m pip install -r requirements-dev.txt
python -m ruff check .
python -m pytest -q
```

Os testes cobrem extensão com caixa preservada, sanitização, schema inválido, datas inválidas, colisões sem sobrescrita, cópia e movimento, origem alterada, espera por estabilidade, extração dos quatro tipos, retry de validação, schema enviado à API, simulação e idempotência do fluxo. A IA é simulada nos testes; para validar sua conta/modelo, execute o exemplo com sua chave.

O CI foi incluído para rodar automaticamente ao fazer push ou abrir PR. A matriz só será comprovada quando executar no GitHub; validação local não comprova Windows ou todas as versões do Python.

## Repositório e desenvolvimento

Código: [Matheuskii/FileMind-Organizador-Inteligente-de-Arquivos](https://github.com/Matheuskii/FileMind-Organizador-Inteligente-de-Arquivos).

Para baixar:

```bash
git clone https://github.com/Matheuskii/FileMind-Organizador-Inteligente-de-Arquivos.git
cd FileMind-Organizador-Inteligente-de-Arquivos
```

Siga a instalação acima e configure `.env` localmente. Antes de contribuir, rode os testes e o lint. Não versione chaves ou documentos pessoais. Nenhuma chave é necessária para rodar o CI.

## Problemas comuns

| Sintoma | Ação |
|---|---|
| `configure GROQ_API_KEY` | Preencha `.env` na pasta em que executa o comando |
| Erro de autenticação | Confira chave e conta; não cole chave em issues |
| HTTP 429 / RateLimitError | Aguarde renovação da cota, reduza texto/volume e rode `--once` |
| BadRequestError com strict | Use modelo compatível ou retire `--strict-server` para Llama |
| Tesseract não encontrado | Instale executável, idiomas e PATH; teste `tesseract --version` |
| Arquivo permanece na origem | Confira simulação, modo copy, limite, erro de extração ou credencial |
| Falha por timeout de estabilidade | Espere o download terminar e rode `--once` |
| Arquivo não aparece | Somente raiz monitorada; verifique extensão e `--scan-existing` |
| Pasta de Downloads não existe | Informe `--watch` com caminho real, inclusive redirecionado ao OneDrive |

Código de saída `1` indica pelo menos uma falha no processamento; `0` indica conclusão sem falhas registradas. A mensagem do log mostra a classe da exceção, sem expor o corpo da resposta da API.

## Referências

- [Groq: Structured Outputs e JSON Object Mode](https://console.groq.com/docs/structured-outputs)
- [Groq: modelos](https://console.groq.com/docs/models)
- [Groq: limites](https://console.groq.com/docs/rate-limits)
- [pypdf: extração de texto e limitações](https://pypdf.readthedocs.io/en/stable/user/extract-text.html)
- [watchdog](https://python-watchdog.readthedocs.io/)
- [Pydantic](https://docs.pydantic.dev/latest/)

## Próximas evoluções

Interface de revisão antes de aplicar; OCR de PDF; fila durável; extração em subprocesso com limites de recursos; tratamento de arquivos escritos continuamente; undo com histórico transacional; integração opcional com modelo local. Não estão implementados nesta versão.
