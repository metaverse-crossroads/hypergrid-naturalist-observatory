use actix::System;
use clap::Parser;
use crossbeam_channel::{unbounded, Sender};
use log::{error, info, warn, LevelFilter};
use metaverse_core::initialize::initialize;
use metaverse_messages::packet::message::{UIMessage, UIResponse};
use metaverse_messages::ui::login_event::Login;
use std::net::UdpSocket;
use std::thread::sleep;
use std::time::Duration;

#[derive(Parser, Debug, Clone)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(short, long, default_value = "Test")]
    first_name: String,

    #[arg(short, long, default_value = "User")]
    last_name: String,

    #[arg(short, long, default_value = "password")]
    password: String,

    #[arg(long, default_value = "http://127.0.0.1:9000/")]
    grid_url: String,

    #[arg(long, default_value_t = 12000)]
    ui_port: u16,

    #[arg(long, default_value_t = 12001)]
    core_port: u16,

    /// Mode: standard, rejection, wallflower, ghost, chatter
    #[arg(long, default_value = "standard")]
    mode: String,
}

fn log_encounter(system: &str, signal: &str, payload: &str) {
    let at = chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true);

    // UA Injection
    let ua = std::env::var("TAG_UA").unwrap_or("".to_string());
    let ua_part = if !ua.is_empty() { format!("\"ua\": \"{}\", ", ua) } else { "".to_string() };

    // Simple escape for JSON
    let payload_safe = payload.replace("\"", "\\\"");

    println!("{{ \"at\": \"{}\", {}\"via\": \"Visitant\", \"sys\": \"{}\", \"sig\": \"{}\", \"val\": \"{}\" }}", at, ua_part, system, signal, payload_safe);
}

fn main() {
    env_logger::builder().filter_level(LevelFilter::Info).init();
    let mut args = Args::parse();

    // Mode-specific logic overrides
    if args.mode == "rejection" {
        args.password = "badpassword".to_string();
    }

    log_encounter("Login", "Start", &format!("URI: {}, User: {} {}, Mode: {}", args.grid_url, args.first_name, args.last_name, args.mode));

    let (sender, receiver) = unbounded();

    // Start the UI Listener (listens for events FROM Core)
    let ui_port = args.ui_port;
    std::thread::spawn(move || {
        let rt = tokio::runtime::Runtime::new().expect("Failed to create Tokio runtime");
        rt.block_on(async {
            listen_for_core_events(ui_port, sender).await;
        });
    });

    // Start the Core actor system
    let core_port_arg = args.core_port;
    let ui_port_arg = args.ui_port;
    std::thread::spawn(move || {
        System::new().block_on(async {
            match initialize(core_port_arg, ui_port_arg).await {
                Ok(handle) => {
                    match handle.await {
                        Ok(()) => info!("The internal system (Core) has departed."),
                        Err(e) => error!("The internal system (Core) faltered: {:?}", e),
                    };
                }
                Err(err) => {
                    error!("Failed to awaken the inner spirit (Core): {:?}", err);
                }
            }
        });
    });

    // Wait for system to spin up
    sleep(Duration::from_secs(2));

    // Send Login Packet to Core
    // info!("The Visitant approaches the Range, offering credentials (Login Packet sent).");
    let login_msg = UIResponse::Login(Login {
        first: args.first_name.clone(),
        last: args.last_name.clone(),
        passwd: args.password.clone(),
        start: "home".to_string(),
        channel: "benthic_deepsea".to_string(),
        agree_to_tos: true,
        read_critical: true,
        url: args.grid_url.clone(),
    });

    let packet_bytes = login_msg.to_bytes();

    let socket = UdpSocket::bind("0.0.0.0:0").expect("Failed to bind sending socket");
    match socket.send_to(&packet_bytes, format!("127.0.0.1:{}", args.core_port)) {
        Ok(_) => {
             // info!("Credentials offered to the Core system.");
        }
        Err(e) => {
            log_encounter("Login", "Fail", &format!("Failed to offer credentials: {:?}", e));
        }
    };

    // Main loop: process events
    // info!("The Visitant waits in the foyer (Listening for events)...");

    // Legacy mode timing
    let start_time = std::time::Instant::now();
    let mut logged_in = false;
    let mut last_message_was_land_update = false;

    loop {
        // Basic timeout check for legacy run modes
        if logged_in {
             if args.mode == "wallflower" {
                 if start_time.elapsed() > Duration::from_secs(90) {
                     break;
                 }
             } else if start_time.elapsed() > Duration::from_secs(30) { // Standard/Chatter wait 30s
                 log_encounter("Logout", "Initiate", "");
                 break;
             }
        }

        // Non-blocking check for messages
        match receiver.recv_timeout(Duration::from_millis(100)) {
            Ok(event) => {
                // If it's not a LandUpdate, reset the flag
                if !matches!(event, UIMessage::LandUpdate(_)) {
                    last_message_was_land_update = false;
                }

                match event {
                    UIMessage::LoginResponse(response) => {
                         log_encounter("Login", "Success", &format!("Agent: {} {}", response.firstname, response.lastname));
                         logged_in = true;

                         if args.mode == "ghost" {
                             log_encounter("Behavior", "Ghost", "Vanishing immediately...");
                             return; // Exit
                         }
                    }
                    UIMessage::Error(e) => {
                        log_encounter("Login", "Fail", &format!("Connection error: {:?}", e));
                        break;
                    }
                    UIMessage::CoarseLocationUpdate(_loc) => {
                        // Suppress
                    }
                    UIMessage::LandUpdate(_) => {
                         if !last_message_was_land_update {
                            log_encounter("Territory", "Impression", "LandUpdate received");
                            last_message_was_land_update = true;
                         }
                    }
                    UIMessage::MeshUpdate(mesh) => {
                         // log_encounter("Territory", "Impression", &format!("MeshUpdate: {:?}", mesh.mesh_type));
                    }
                    UIMessage::CameraPosition(_cam) => {
                         // Suppress
                    }
                    UIMessage::ChatFromSimulator(chat) => {
                         log_encounter("Chat", "Heard", &format!("From: {}, Msg: {}", chat.from_name, chat.message));
                    }
                    other => {
                        log_encounter("Territory", "Unhandled", &format!("{:?}", other));
                    }
                }
            }
            Err(_) => {
                // Timeout, continue loop
            }
        }
    }
}

async fn listen_for_core_events(port: u16, sender: Sender<UIMessage>) {
    let addr = format!("127.0.0.1:{}", port);
    let socket = tokio::net::UdpSocket::bind(&addr).await.expect("Failed to bind UDP socket");

    loop {
        let mut buf = [0u8; 65535];
        match socket.recv_from(&mut buf).await {
            Ok((n, _)) => {
                if let Ok(packet) = UIMessage::from_bytes(&buf[..n]) {
                    if let Err(e) = sender.send(packet) {
                        warn!("Failed to pass message to consciousness: {:?}", e)
                    };
                }
            }
            Err(e) => {
                warn!("Failed to hear the Core: {}", e)
            }
        }
    }
}
