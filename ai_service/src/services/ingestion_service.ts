import fs from 'fs/promises';
import path from 'path';
import { RecursiveCharacterTextSplitter } from '@langchain/textsplitters';
import { PDFLoader } from '@langchain/community/document_loaders/fs/pdf';
import { getActiveStrategy } from '../config/ingestion_config';
import { saveDocumentChunk } from '../vectorstore/documentVectorStore';

/**
 * Emulador de MarkdownHeaderTextSplitter para o ecossistema JS/TS (onde não está disponível nativamente).
 * Permite quebrar a hierarquia do documento por cabeçalhos e extrair metadados estruturados correspondentes.
 */
export class MarkdownHeaderTextSplitter {
  private headersToSplitOn: [string, string][];
  private stripHeaders: boolean;

  constructor(fields: { headersToSplitOn: [string, string][]; stripHeaders?: boolean }) {
    this.headersToSplitOn = fields.headersToSplitOn;
    this.stripHeaders = fields.stripHeaders ?? true;
  }

  splitText(text: string): { pageContent: string; metadata: Record<string, any> }[] {
    // Ordenar cabeçalhos por tamanho decrescente para evitar conflito de prefixo (ex: ### antes de ##)
    const sortedHeaders = [...this.headersToSplitOn].sort((a, b) => b[0].length - a[0].length);
    const lines = text.split('\n');
    
    const documents: { pageContent: string; metadata: Record<string, any> }[] = [];
    let currentMetadata: Record<string, any> = {};
    let currentChunkLines: string[] = [];

    for (const line of lines) {
      let matchedHeader: [string, string] | undefined = undefined;
      
      for (const [symbol, key] of sortedHeaders) {
        if (line.startsWith(symbol + ' ') || line === symbol) {
          matchedHeader = [symbol, key];
          break;
        }
      }

      if (matchedHeader) {
        if (currentChunkLines.length > 0) {
          documents.push({
            pageContent: currentChunkLines.join('\n'),
            metadata: { ...currentMetadata },
          });
          currentChunkLines = [];
        }

        const [matchedSymbol, matchedKey] = matchedHeader;
        
        // Limpar chaves de metadados de hierarquia igual ou inferior
        for (const [symbol, key] of sortedHeaders) {
          if (symbol.length >= matchedSymbol.length) {
            delete currentMetadata[key];
          }
        }

        const headerText = line.substring(matchedSymbol.length).trim();
        currentMetadata[matchedKey] = headerText;

        if (!this.stripHeaders) {
          currentChunkLines.push(line);
        }
      } else {
        currentChunkLines.push(line);
      }
    }

    if (currentChunkLines.length > 0) {
      documents.push({
        pageContent: currentChunkLines.join('\n'),
        metadata: { ...currentMetadata },
      });
    }

    return documents;
  }
}

/**
 * Pipeline principal de ingestão.
 */
export async function ingestFile(filePath: string): Promise<void> {
  const extension = path.extname(filePath).toLowerCase();
  const fileName = path.basename(filePath);
  
  console.log(`[Ingestion] Iniciando processamento: ${fileName}`);

  let content: string = '';
  let category: 'policy' | 'manual' = extension === '.md' ? 'policy' : 'manual';

  if (extension === '.md') {
    content = await fs.readFile(filePath, 'utf-8');
    
    // Obter estratégia de splitting
    const strategy = getActiveStrategy();

    // Estágio 1: Quebra da hierarquia do documento usando cabeçalhos
    const markdownSplitter = new MarkdownHeaderTextSplitter({
      headersToSplitOn: [
        ["##", "documento_origem"],
        ["###", "secao_principal"],
        ["####", "sub_secao"],
        ["#####", "caso_de_teste_ou_topico"],
      ],
      stripHeaders: false,
    });

    const mdDocs = markdownSplitter.splitText(content);

    // Estágio 2: Split secundário de caracteres baseado na estratégia ativa
    const recursiveSplitter = new RecursiveCharacterTextSplitter({
      chunkSize: strategy.chunkSize,
      chunkOverlap: strategy.chunkOverlap,
    });

    const chunks = await recursiveSplitter.splitDocuments(mdDocs);
    console.log(`[Ingestion] ${fileName} fragmentado em ${chunks.length} partes.`);

    for (const chunk of chunks) {
      await saveDocumentChunk({
        content: chunk.pageContent,
        source: fileName,
        category: category,
        metadata: {
          ...chunk.metadata,
          ingested_at: new Date().toISOString(),
          strategy: strategy,
        }
      });
    }
  } else if (extension === '.pdf') {
    const loader = new PDFLoader(filePath);
    const docs = await loader.load();
    content = docs.map(d => d.pageContent).join('\n');

    // Obter estratégia de splitting
    const strategy = getActiveStrategy();
    const splitter = new RecursiveCharacterTextSplitter({
      chunkSize: strategy.chunkSize,
      chunkOverlap: strategy.chunkOverlap,
    });

    const chunks = await splitter.splitText(content);
    console.log(`[Ingestion] ${fileName} fragmentado em ${chunks.length} partes.`);

    for (const chunk of chunks) {
      await saveDocumentChunk({
        content: chunk,
        source: fileName,
        category: category,
        metadata: {
          ingested_at: new Date().toISOString(),
          strategy: strategy,
        }
      });
    }
  } else {
    throw new Error(`Extensão não suportada: ${extension}`);
  }

  console.log(`[Ingestion] Finalizado: ${fileName}`);
}

/**
 * Varre uma pasta e processa todos os arquivos suportados.
 */
export async function ingestDirectory(dirPath: string): Promise<void> {
  const files = await fs.readdir(dirPath);
  
  for (const file of files) {
    const fullPath = path.join(dirPath, file);
    const stat = await fs.stat(fullPath);
    
    if (stat.isFile() && (file.endsWith('.md') || file.endsWith('.pdf'))) {
      try {
        await ingestFile(fullPath);
      } catch (err) {
        console.error(`Erro ao processar ${file}:`, err);
      }
    }
  }
}
