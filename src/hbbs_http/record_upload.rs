use crate::hbbs_http::create_http_client_with_url;
use bytes::Bytes;
use hbb_common::{bail, config::Config, lazy_static, log, ResultType};
use reqwest::blocking::{Body, Client};
use scrap::record::RecordState;
use serde::Serialize;
use serde_json::{json, Map, Value};
use std::{
    fs::File,
    io::{prelude::*, SeekFrom},
    sync::{mpsc::Receiver, Arc, Mutex},
    time::{Duration, Instant},
};

use crate::audio_service::new;

// useful constants for uploader...
// @escra, we have changed it 
const MAX_HEADER_LEN: usize = 256; // 1024; 
const SHOULD_SEND_TIME: Duration = Duration::from_secs(1);
const SHOULD_SEND_SIZE: u64 = 256 * 256; // 1024 * 1024;

// variable called enable to check the status of the uploading...
lazy_static::lazy_static! {
    // @escra , changing the enable variable to record upload 
    // static ref ENABLE: Arc<Mutex<bool>> = Arc::new(Mutex::new(true));
    // If you are going to change this one to the true, then you need to 
    // change the toml file too.... 
    static ref ENABLE: Arc<Mutex<bool>> =  Default::default();

    // Enabled by default so local testing streams recordings automatically.
    // static ref ENABLE: Arc<Mutex<bool>> = Arc::new(Mutex::new(true));
}

pub fn is_enable() -> bool {
    ENABLE.lock().unwrap().clone()
}

pub fn change_enable(status: bool) {
    // if b{
        *ENABLE.lock().unwrap() = status;
    // }
    // else {     
    // }

}


pub fn run(rx: Receiver<RecordState>) {

    // first we create the uploader
    // the uploader uses 'api-server' and 'custom-rendezvous-server'
    std::thread::spawn(move || {
        let mut api_server = crate::get_api_server(
            Config::get_option("api-server"),
            Config::get_option("custom-rendezvous-server"),
        );
        // if true ||  api_server.is_empty() || api_server.contains("rustdesk.com") {
        //     // Default to local uploader server when nothing custom is configured.
        //     api_server = match local_ipaddress::get() {
        //         Some(addr) => format!("http://{}:8080", addr),
        //         None => "http://127.0.0.1:8080".to_owned(),
        //     };
        // }
        // This URL is used for TLS connectivity testing and fallback detection.
        let login_option_url = format!("{}/api/login-options", &api_server);
        let client = create_http_client_with_url(&login_option_url);
        let mut uploader = RecordUploader {
            client,
            api_server,
            filepath: Default::default(),
            filename: Default::default(),
            upload_size: Default::default(),
            running: Default::default(),
            last_send: Instant::now(),
        };
        loop {
            if let Err(e) = match rx.recv() {
                Ok(state) => match state {
                    RecordState::NewFile(filepath) => uploader.handle_new_file(filepath),
                    RecordState::NewFrame => {
                        if uploader.running {
                            uploader.handle_frame(false)
                        } else {
                            Ok(())
                        }
                    }
                    RecordState::WriteTail => {
                        if uploader.running {
                            uploader.handle_tail()
                        } else {
                            Ok(())
                        }
                    }
                    RecordState::RemoveFile => {
                        if uploader.running {
                            uploader.handle_remove()
                        } else {
                            Ok(())
                        }
                    }
                },
                Err(e) => {
                    log::trace!("upload thread stop: {}", e);
                    break;
                }
            } {
                uploader.running = false;
                log::error!("upload stop: {}", e);
            }
        }
    });
}

struct RecordUploader {
    client: Client,
    api_server: String,
    filepath: String,
    filename: String,
    upload_size: u64,
    running: bool,
    last_send: Instant,
}

// implementation (functions of the record uploader)
// namely creating new file, sending recording, removing the file
impl RecordUploader {
    fn send<Q>(&self, query: &Q, body: &Vec<u8>) -> ResultType<()>
    where
        Q: Serialize + ?Sized,
        //B: Into<Body>,
    {
        match self
            .client
            .post(format!("{}/api/record", self.api_server))
            .query(query)
            .json(&json!({"body": body}))
            .send()
        {
            Ok(resp) => {
                if let Ok(m) = resp.json::<Map<String, serde_json::Value>>() {
                    if let Some(e) = m.get("error") {
                        bail!(e.to_string());
                    }
                }
                log::info!("Here is the sent request: {:?}", self.client);
                Ok(())
            }
            Err(e) => bail!(e.to_string()),
        }
    }

    // any action above is happening by the queries.
    // for the action specified, we give the query accordingly.
    // Those are happening in the api-server {api_server}/api/record directory or link

    fn handle_new_file(&mut self, filepath: String) -> ResultType<()> {
        match std::path::PathBuf::from(&filepath).file_name() {
            Some(filename) => match filename.to_owned().into_string() {
                Ok(filename) => {
                    // @escra, here is an attempt to send manipulated bits. 
                    // self.send(&[("type", "attemptToSend")], Bytes::from("Hey there, can we use this"))?;
                    self.filename = filename.clone();
                    self.filepath = filepath.clone();
                    self.upload_size = 0;
                    self.running = true;
                    self.last_send = Instant::now();
                    self.send(&[("type", "new"), ("file", &filename)], &Vec::new())?;
                    Ok(())
                }
                Err(_) => bail!("can't parse filename:{:?}", filename),
            },
            None => bail!("can't parse filepath:{}", filepath),
        }
    }

    fn handle_frame(&mut self, flush: bool) -> ResultType<()> {
        if !flush && self.last_send.elapsed() < SHOULD_SEND_TIME {
            return Ok(());
        }
        match File::open(&self.filepath) {
            Ok(mut file) => match file.metadata() {
                Ok(m) => {
                    let len = m.len();
                    if len <= self.upload_size {
                        return Ok(());
                    }
                    if !flush && len - self.upload_size < SHOULD_SEND_SIZE {
                        return Ok(());
                    }
                    let mut buf = Vec::new();
                    match file.seek(SeekFrom::Start(self.upload_size)) {
                        Ok(_) => match file.read_to_end(&mut buf) {
                            Ok(length) => {
                                // @escra , buf printing... 
                                log::info!("Here is the buf: {:?}", &buf);
                                self.send(
                                    &[
                                        ("type", "part"),
                                        ("file", &self.filename),
                                        ("offset", &self.upload_size.to_string()),
                                        ("length", &length.to_string()),
                                    ],
                                    &buf,
                                )?;
                                
                                self.upload_size = len;
                                self.last_send = Instant::now();
                                Ok(())
                            }
                            Err(e) => bail!(e.to_string()),
                        },
                        Err(e) => bail!(e.to_string()),
                    }
                }
                Err(e) => bail!(e.to_string()),
            },
            Err(e) => bail!(e.to_string()),
        }
    }

    fn handle_tail(&mut self) -> ResultType<()> {
        self.handle_frame(true)?;
        match File::open(&self.filepath) {
            Ok(mut file) => {
                let mut buf = vec![0u8; MAX_HEADER_LEN];
                match file.read(&mut buf) {
                    Ok(length) => {
                        buf.truncate(length);
                        self.send(
                            &[
                                ("type", "tail"),
                                ("file", &self.filename),
                                ("offset", "0"),
                                ("length", &length.to_string()),
                            ],
                            &buf,
                        )?;
                        log::info!("upload success, file: {}", self.filename);
                        Ok(())
                    }
                    Err(e) => bail!(e.to_string()),
                }
            }
            Err(e) => bail!(e.to_string()),
        }
    }

    fn handle_remove(&mut self) -> ResultType<()> {
        self.send(
            &[("type", "remove"), ("file", &self.filename)],
            &Vec::new(),
        )?;
        Ok(())
    }

    fn jsoning(buf: Vec<u8>) -> Value {
        json!({"body" : buf})
    }
}
