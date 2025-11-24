use std::{
    path::{Path, PathBuf},
    sync::Arc,
};

use actix_web::{
    middleware::Logger,
    web::{self, Data},
    App, HttpResponse, HttpServer, Responder,
};
use serde::Deserialize;
use serde_json::json;
use thiserror::Error;
use tokio::{
    fs::{self, OpenOptions},
    io::{AsyncSeekExt, AsyncWriteExt},
    sync::Mutex,
};
use tracing::{error, info};
use tracing_subscriber::EnvFilter;

#[derive(Clone)]
struct StorageConfig {
    root: PathBuf,
    video_dir: PathBuf,
    audio_dir: PathBuf,
    chat_dir: PathBuf,
}

impl StorageConfig {
    fn new<P: AsRef<Path>>(root: P) -> Self {
        let root = root.as_ref().to_path_buf();
        Self {
            video_dir: root.join("video"),
            audio_dir: root.join("audio"),
            chat_dir: root.join("chat"),
            root,
        }
    }

    async fn ensure_dirs(&self) -> Result<(), std::io::Error> {
        fs::create_dir_all(&self.video_dir).await?;
        fs::create_dir_all(&self.audio_dir).await?;
        fs::create_dir_all(&self.chat_dir).await?;
        Ok(())
    }
}

#[derive(Clone)]
struct AppState {
    storage: StorageConfig,
    /// Mutex protects file-system operations that must be sequential per file.
    /// This is a naive approach now but provides extensibility for future state management
    /// (e.g. storing metadata in memory, or DB handles).
    guard: Arc<Mutex<()>>,
}

impl AppState {
    async fn new<P: AsRef<Path>>(root: P) -> std::io::Result<Self> {
        let storage = StorageConfig::new(root);
        storage.ensure_dirs().await?;
        Ok(Self {
            storage,
            guard: Arc::new(Mutex::new(())),
        })
    }
}

#[derive(Debug, Deserialize)]
struct ChunkQuery {
    #[serde(rename = "type")]
    chunk_type: String,
    file: String,
    offset: Option<u64>,
    length: Option<u64>,
}

#[derive(Debug, Deserialize)]
struct ChunkBody {
    body: Vec<u8>,
}

#[derive(Debug, Deserialize)]
struct ChatPayload {
    session_id: String,
    from: String,
    to: String,
    text: String,
    timestamp: Option<String>,
}

#[derive(Debug, Error)]
enum UploadError {
    #[error("invalid chunk type")]
    InvalidType,
    #[error("storage error: {0}")]
    Io(#[from] std::io::Error),
}

type UploadResult<T> = Result<T, UploadError>;

async fn handle_chunk(
    base_dir: &Path,
    query: ChunkQuery,
    body: ChunkBody,
) -> UploadResult<()> {
    let file_path = base_dir.join(&query.file);
    match query.chunk_type.as_str() {
        "new" => {
            OpenOptions::new()
                .create(true)
                .write(true)
                .truncate(true)
                .open(&file_path)
                .await?;
        }
        "part" => {
            let offset = query.offset.unwrap_or(0);
            let mut file = OpenOptions::new()
                .create(true)
                .write(true)
                .read(true)
                .open(&file_path)
                .await?;
            file.seek(std::io::SeekFrom::Start(offset)).await?;
            file.write_all(&body.body).await?;
            file.flush().await?;
        }
        "tail" => {
            let offset = query.offset.unwrap_or(0);
            let mut file = OpenOptions::new()
                .create(true)
                .write(true)
                .read(true)
                .open(&file_path)
                .await?;
            file.seek(std::io::SeekFrom::Start(offset)).await?;
            if !body.body.is_empty() {
                file.write_all(&body.body).await?;
                file.flush().await?;
            }
        }
        "remove" => {
            if fs::remove_file(&file_path).await.is_err() {
                // ignore errors when removing, file may not exist
            }
        }
        _ => return Err(UploadError::InvalidType),
    }

    Ok(())
}

async fn record_endpoint(
    state: Data<AppState>,
    query: web::Query<ChunkQuery>,
    payload: web::Json<ChunkBody>,
) -> impl Responder {
    let _guard = state.guard.lock().await;
    match handle_chunk(&state.storage.video_dir, query.into_inner(), payload.into_inner()).await {
        Ok(_) => HttpResponse::Ok().json(json!({ "status": "ok" })),
        Err(err) => {
            error!("record upload failed: {err}");
            HttpResponse::BadRequest().json(json!({ "error": err.to_string() }))
        }
    }
}

async fn audio_endpoint(
    state: Data<AppState>,
    query: web::Query<ChunkQuery>,
    payload: web::Json<ChunkBody>,
) -> impl Responder {
    let _guard = state.guard.lock().await;
    match handle_chunk(&state.storage.audio_dir, query.into_inner(), payload.into_inner()).await {
        Ok(_) => HttpResponse::Ok().json(json!({ "status": "ok" })),
        Err(err) => {
            error!("audio upload failed: {err}");
            HttpResponse::BadRequest().json(json!({ "error": err.to_string() }))
        }
    }
}

async fn chat_endpoint(
    state: Data<AppState>,
    payload: web::Json<ChatPayload>,
) -> impl Responder {
    let mut chat_file = state.storage.chat_dir.join("chat.log");
    // Per-session file for future extensibility
    if !payload.session_id.is_empty() {
        chat_file = state.storage.chat_dir.join(format!("{}.log", payload.session_id));
    }

    let line = json!({
        "sessionId": payload.session_id,
        "from": payload.from,
        "to": payload.to,
        "text": payload.text,
        "timestamp": payload.timestamp,
    })
    .to_string();

    if let Err(err) = append_line(&chat_file, &line).await {
        error!("chat write failed: {err}");
        return HttpResponse::BadRequest().json(json!({ "error": err.to_string() }));
    }

    HttpResponse::Ok().json(json!({ "status": "ok" }))
}

async fn append_line(path: &Path, line: &str) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).await?;
    }
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)
        .await?;
    file.write_all(line.as_bytes()).await?;
    file.write_all(b"\n").await?;
    file.flush().await?;
    Ok(())
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let bind_addr = std::env::var("BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:8080".to_string());
    let storage_dir = std::env::var("UPLOAD_DIR").unwrap_or_else(|_| "./uploaded_sessions".to_string());

    let state = AppState::new(&storage_dir).await?;

    println!("Session uploader server starting...");

    info!("session uploader server listening on {bind_addr}");
    info!("video storage dir: {}", state.storage.video_dir.display());
    info!("audio storage dir: {}", state.storage.audio_dir.display());
    info!("chat storage dir: {}", state.storage.chat_dir.display());

    HttpServer::new(move || {
        App::new()
            .app_data(Data::new(state.clone()))
            .wrap(Logger::default())
            .route("/api/record", web::post().to(record_endpoint))
            .route("/api/audio", web::post().to(audio_endpoint))
            .route("/api/chat", web::post().to(chat_endpoint))
    })
    .bind(&bind_addr)?
    .run()
    .await
}



