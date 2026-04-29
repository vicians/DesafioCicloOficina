import swaggerJsDoc from 'swagger-jsdoc';

const options: swaggerJsDoc.Options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Tião API | Em desenvolvimento',
      version: '0.1.0',
      description: 'Documentação da API. Mais detalhes do projeto e dos endpoints serão documentados aqui posteriormente, atualmente estamos em fase inicial de desenvolvimento.',
    },
    servers: [
      {
        url: 'http://localhost:3000',
        description: 'Testes locais - Dev',
      },
    ],
  },
  apis: ['./src/routes/*.ts'],
};

const swaggerSpec = swaggerJsDoc(options);

export { swaggerSpec };