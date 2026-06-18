# Guía Detallada: Configuración de AWS y GitHub para TicketGo

Esta guía explica paso a paso cómo preparar tu cuenta de AWS y GitHub para el primer despliegue (Puntos 2, 3 y 4).

---

## ☁️ Punto 2: Preparar el Backend de Terraform (El "Cerebro")

Terraform guarda un archivo llamado `terraform.tfstate`. Si lo pierdes, pierdes el control de tu infraestructura. Por eso lo guardaremos en AWS S3 y bloquearemos accesos concurrentes con DynamoDB.

### Paso 2.1: Crear el Bucket S3
1. Abre tu terminal WSL y asegúrate de tener credenciales de AWS (`aws configure`).
2. Ejecuta este comando para crear un bucket único (añade la fecha/hora para que el nombre no choque con otro en el mundo):
   ```bash
   aws s3api create-bucket \
       --bucket ticketgo-tfstate-prod-$(date +%s) \
       --region us-east-2 \
       --create-bucket-configuration LocationConstraint=us-east-2
   ```
3. El comando te devolverá algo así:
   `"Location": "http://ticketgo-tfstate-prod-171855...s3.amazonaws.com/"`
4. **Copia el nombre exacto de tu bucket** (ej. `ticketgo-tfstate-prod-171855...`).
5. Abre el archivo `infra/environments/prod/providers.tf` en VS Code.
6. En la línea 20, cambia `"ticketgo-tfstate-prod"` por el nombre exacto que acabas de copiar.

### Paso 2.2: Crear la Tabla DynamoDB (Bloqueo de Estado)
1. Ejecuta este comando para crear la tabla de bloqueos:
   ```bash
   aws dynamodb create-table \
       --table-name ticketgo-tfstate-lock \
       --attribute-definitions AttributeName=LockID,AttributeType=S \
       --key-schema AttributeName=LockID,KeyType=HASH \
       --billing-mode PAY_PER_REQUEST \
       --region us-east-2
   ```
2. No necesitas modificar ningún archivo tras este paso, el código ya busca la tabla `"ticketgo-tfstate-lock"`.

---

## 🔒 Punto 3: Solicitar el Certificado SSL (HTTPS)

CloudFront requiere obligatoriamente que tu certificado SSL esté en la región de **Norte de Virginia (`us-east-1`)**, sin importar que tu base de datos y servidores estén en Ohio.

### Paso 3.1: Solicitar el certificado
1. Ejecuta:
   ```bash
   aws acm request-certificate \
       --domain-name ticketgo.pe \
       --subject-alternative-names "*.ticketgo.pe" \
       --validation-method DNS \
       --region us-east-1
   ```
2. El comando te devolverá un **`CertificateArn`** (ej. `arn:aws:acm:us-east-1:123456789:certificate/abcd...`).
3. **Copia ese ARN.**
4. Abre el archivo `infra/environments/prod/terraform.tfvars`.
5. En la línea 39 (`acm_certificate_arn`), pega el ARN que copiaste.

### Paso 3.2: Validar el dominio (Muy Importante)
El certificado no funcionará hasta que AWS confirme que eres el dueño de `ticketgo.pe`.
1. Entra a la consola web de AWS.
2. Arriba a la derecha, asegúrate de estar en la región **N. Virginia (us-east-1)**.
3. Busca el servicio **Certificate Manager (ACM)**.
4. Verás tu certificado en estado **Pending validation (Validación pendiente)**.
5. Haz clic en el ID del certificado.
6. En la sección "Domains", verás un botón que dice **"Create records in Route 53"** (Crear registros en Route 53). Haz clic ahí y confirma. 
   *(Si compraste tu dominio fuera de AWS, por ejemplo en GoDaddy, tendrás que copiar los valores CNAME Name y CNAME Value que ahí te muestran y pegarlos manualmente en el panel DNS de GoDaddy).*
7. Espera unos minutos. El estado cambiará de "Pending" a **"Issued" (Emitido)**.

---

## 🔑 Punto 4: Secretos de GitHub (CI/CD)

Para que GitHub Actions pueda ejecutar Terraform y subir tus imágenes de Docker automáticamente, necesita permisos y algunas variables.

### Paso 4.1: Crear un Usuario IAM (Para GitHub)
*Nota: La forma más segura es OIDC, pero por simplicidad para iniciar, usaremos llaves estáticas (Access Keys).*
1. Entra a la consola de AWS y busca el servicio **IAM**.
2. Ve a **Users** > **Create user**. Llámalo `github-actions-deployer`.
3. Selecciona **"Attach policies directly"** y asígnale el permiso **`AdministratorAccess`**.
4. Una vez creado, entra al usuario, ve a la pestaña **"Security credentials"**.
5. Haz clic en **"Create access key"** (selecciona "Third-party service").
6. **Copia y guarda** el `Access Key ID` y el `Secret Access Key` (este último solo se muestra una vez).

### Paso 4.2: Guardar las llaves en GitHub
1. Abre tu repositorio en GitHub.com.
2. Ve a la pestaña **Settings** (Configuración).
3. En el menú izquierdo, despliega **Secrets and variables** y haz clic en **Actions**.
4. Haz clic en el botón verde **"New repository secret"**.
5. Agrega los siguientes 3 secretos uno por uno:

| Name (Nombre) | Secret (Valor) |
|---------------|----------------|
| `AWS_ACCESS_KEY_ID` | Pega aquí tu Access Key de AWS. |
| `AWS_SECRET_ACCESS_KEY`| Pega aquí tu Secret Key de AWS. |
| `TF_VAR_db_username` | Escribe: `ticketgo_admin` (o el que quieras). |

*(Ya están listos los flujos de GitHub para buscar estos secretos).*

---
**¡Fin de la configuración base!**
En este punto, estás listo para entrar a `infra/environments/prod` en tu terminal y correr `terraform init` y `terraform apply`.
