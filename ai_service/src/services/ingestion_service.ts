import fs from 'fs/promises';
import path from 'path';
import { RecursiveCharacterTextSplitter } from '@langchain/textsplitters';
import { PDFLoader } from '@langchain/community/document_loaders/fs/pdf';
import { getActiveStrategy } from '../config/ingestion_config';
import { saveDocumentChunk } from '../vectorstore/documentVectorStore';

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
  } else if (extension === '.pdf') {
    const loader = new PDFLoader(filePath);
    const docs = await loader.load();
    content = docs.map(d => d.pageContent).join('\n');
  } else {
    throw new Error(`Extensão não suportada: ${extension}`);
  }

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
