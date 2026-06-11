/**
 * apps/worker-async/index.js
 * Lambda Worker — Procesamiento asíncrono de compra de tickets TicketGo
 *
 * Patrón: ReportBatchItemFailures — solo falla los mensajes específicos
 * que no se pudieron procesar, sin reintentar mensajes exitosos.
 */

const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");

const secretsClient = new SecretsManagerClient({ region: process.env.AWS_REGION });

// Cache de secretos para evitar llamadas repetidas a Secrets Manager
let dbCredentials = null;

async function getDbCredentials() {
  if (dbCredentials) return dbCredentials;

  const command = new GetSecretValueCommand({ SecretId: process.env.DB_SECRET_ARN });
  const response = await secretsClient.send(command);
  dbCredentials = JSON.parse(response.SecretString);
  return dbCredentials;
}

/**
 * Handler principal de Lambda
 * El Event Source Mapping de SQS entrega hasta `batch_size` mensajes por invocación.
 */
exports.handler = async (event) => {
  const credentials = await getDbCredentials();
  const batchItemFailures = [];

  console.log(`Procesando lote de ${event.Records.length} mensajes`);

  await Promise.allSettled(
    event.Records.map(async (record) => {
      try {
        const body = JSON.parse(record.body);

        if (body.type !== "ticket_purchase") {
          // Mensaje no reconocido — log y skip sin error
          console.warn(`Tipo de mensaje desconocido: ${body.type}`, { messageId: record.messageId });
          return;
        }

        // TODO: Implementar lógica de negocio:
        // 1. Verificar disponibilidad de tickets en DB
        // 2. Crear registro de compra
        // 3. Enviar email de confirmación (SES)
        // 4. Actualizar inventario de tickets
        console.log(`✅ Ticket procesado: ${body.ticketId}`, {
          userId: body.userId,
          eventId: body.eventId,
          quantity: body.quantity,
        });

      } catch (error) {
        console.error(`❌ Error procesando mensaje ${record.messageId}:`, error);
        // Reportar solo este mensaje como fallido (los demás se consideran exitosos)
        batchItemFailures.push({ itemIdentifier: record.messageId });
      }
    })
  );

  // ReportBatchItemFailures: solo los mensajes en esta lista se reencolarán
  return { batchItemFailures };
};
