use actix::System;
use clap::Parser;
use crossbeam_channel::{unbounded, Sender};
use log::{error, info, warn, LevelFilter};
use metaverse_core::initialize::initialize;
use metaverse_messages::packet::message::{UIMessage, UIResponse};
use metaverse_messages::ui::login_event::Login;
use metaverse_messages::ui::chat_from_viewer::ChatFromUI;
use metaverse_messages::udp::agent::agent_update::AgentUpdate;
use std::net::UdpSocket;
use std::thread::sleep;
use std::time::Duration;
use std::io::{self, BufRead};

#[derive(Parser, Debug, Clone)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(long = "firstname", visible_alias = "user", default_value = "Test")]
    first_name: String,

    #[arg(long = "lastname", default_value = "User")]
    last_name: String,

    #[arg(long = "password", default_value = "password")]
    password: String,

    #[arg(long = "uri", default_value = "http://127.0.0.1:9000/")]
    uri: String,

    #[arg(long, default_value_t = 12000)]
    ui_port: u16,

    #[arg(long, default_value_t = 12001)]
    core_port: u16,

    /// Mode: standard, rejection, wallflower, ghost, chatter, repl
    #[arg(long = "mode", default_value = "standard")]
    mode: String,

    /// Rez a primitive on login
    #[arg(long = "rez", default_value_t = false)]
    rez: bool,
}

// Commands from stdin
enum Command {
    Chat(String),
    Logout,
    Exit,
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

    log_encounter("Login", "Start", &format!("URI: {}, User: {} {}, Mode: {}", args.uri, args.first_name, args.last_name, args.mode));

    let (sender, receiver) = unbounded();
    let (cmd_sender, cmd_receiver) = unbounded();

    // Start stdin listener
    std::thread::spawn(move || {
        println!("benthic_deepsea_client REPL. Commands: CHAT, LOGOUT, EXIT");
        let stdin = io::stdin();
        let handle = stdin.lock();
        for line in handle.lines() {
            if let Ok(l) = line {
                let l = l.trim();
                log_encounter("STDIN", "COMMAND", l);
                if l.starts_with("CHAT ") {
                    let msg = l[5..].to_string();
                    let _ = cmd_sender.send(Command::Chat(msg));
                } else if l == "LOGOUT" {
                    let _ = cmd_sender.send(Command::Logout);
                } else if l == "EXIT" {
                    let _ = cmd_sender.send(Command::Exit);
                }
            }
        }
    });

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
    let login_msg = UIResponse::Login(Login {
        first: args.first_name.clone(),
        last: args.last_name.clone(),
        passwd: args.password.clone(),
        start: "home".to_string(),
        channel: "benthic_deepsea".to_string(),
        agree_to_tos: true,
        read_critical: true,
        url: args.uri.clone(),
    });

    let packet_bytes = login_msg.to_bytes();

    let socket = UdpSocket::bind("0.0.0.0:0").expect("Failed to bind sending socket");

    // Define target address
    let core_addr = format!("127.0.0.1:{}", args.core_port);

    match socket.send_to(&packet_bytes, &core_addr) {
        Ok(_) => {
             // info!("Credentials offered to the Core system.");
        }
        Err(e) => {
            log_encounter("Login", "Fail", &format!("Failed to offer credentials: {:?}", e));
        }
    };

    // Main loop: process events
    let start_time = std::time::Instant::now();
    let mut logged_in = false;
    let mut last_message_was_land_update = false;

    loop {
        // Handle Stdin Commands
        while let Ok(cmd) = cmd_receiver.try_recv() {
             match cmd {
                 Command::Chat(msg) => {
                     // Use ChatFromUI struct as expected by UIResponse::ChatFromViewer
                     use metaverse_messages::udp::chat::ChatType;

                     let chat_packet = UIResponse::ChatFromViewer(ChatFromUI {
                         message: msg,
                         channel: 0,
                         message_type: ChatType::Normal,
                     });
                     let bytes = chat_packet.to_bytes();
                     if let Err(e) = socket.send_to(&bytes, &core_addr) {
                         error!("Failed to send chat: {:?}", e);
                     }
                 },
                 Command::Logout => {
                     log_encounter("Logout", "TODO", "Director requested logout");
                     return;
                 },
                 Command::Exit => {
                     log_encounter("Exit", "TODO", "Director requested exit");
                     std::process::exit(0);
                    //  return;
                 }
             }
        }

        // Auto-Logout Logic (Legacy Modes)
        if logged_in {
             if args.mode == "wallflower" {
                 if start_time.elapsed() > Duration::from_secs(90) {
                     break;
                 }
             } else if args.mode == "standard" || args.mode == "chatter" {
                  if start_time.elapsed() > Duration::from_secs(30) {
                      log_encounter("Logout", "Initiate", "Timeout");
                      break;
                  }
             }
             // "repl" mode has no timeout
        }

        // Non-blocking check for messages
        match receiver.recv_timeout(Duration::from_millis(50)) {
            Ok(event) => {
                if !matches!(event, UIMessage::LandUpdate(_)) {
                    last_message_was_land_update = false;
                }

                match event {
                    UIMessage::LoginResponse(response) => {
                         log_encounter("Login", "Success", &format!("Agent: {} {}", response.firstname, response.lastname));
                         logged_in = true;

                         // Rez object if requested
                         if args.rez {
                            // Do nothing. Feature not implemented.
                         }

                         // Send initial AgentUpdate to confirm presence
                         let au = UIResponse::AgentUpdate(AgentUpdate::default());
                         let bytes = au.to_bytes();
                         if let Err(e) = socket.send_to(&bytes, &core_addr) {
                             error!("Failed to send AgentUpdate: {:?}", e);
                         }

                         if args.mode == "ghost" {
                             log_encounter("Behavior", "Ghost", "Vanishing immediately...");
                             return;
                         }
                    }
                    UIMessage::Error(e) => {
                        log_encounter("Login", "Fail", &format!("Connection error: {:?}", e));
                        break;
                    }
                    UIMessage::CoarseLocationUpdate(_loc) => {}
                    UIMessage::LandUpdate(_) => {
                         if !last_message_was_land_update {
                            log_encounter("Territory", "Impression", "LandUpdate received");
                            last_message_was_land_update = true;
                         }
                    }
                    UIMessage::MeshUpdate(_mesh) => {}
                    UIMessage::CameraPosition(_cam) => {}
                    UIMessage::ChatFromSimulator(chat) => {
                         log_encounter("Chat", "Heard", &format!("From: {}, Msg: {}", chat.from_name, chat.message));
                    }
                    UIMessage::DisableSimulator(_) => {
                        log_encounter("Alert", "Heard", "Simulation Closing");
                    }
                    // other => { log_encounter("Territory", "Unhandled", &format!("{:?}", other)); }
                }
            }
            Err(_) => {
                // Timeout
            }
        }
    }
}

async fn listen_for_core_events(port: u16, sender: Sender<UIMessage>) {
    let addr = format!("127.0.0.1:{}", port);
    let socket = tokio::net::UdpSocket::bind(&addr).await.expect("Failed to bind UDP socket");
    info!("DeepSea: Listening for Core events on {}", addr);

    loop {
        let mut buf = [0u8; 65535];
        match socket.recv_from(&mut buf).await {
            Ok((n, _)) => {
                match UIMessage::from_bytes(&buf[..n]) {
                    Ok(packet) => {
                        if let Err(e) = sender.send(packet) {
                            warn!("Failed to pass message to consciousness: {:?}", e)
                        };
                    }
                    Err(e) => {
                        warn!("Failed to deserialize UIMessage: {:?}", e);
                        // Log the raw buffer for debugging
                        warn!("Raw buffer: {:?}", &buf[..n]);
                    }
                }
            }
            Err(e) => {
                warn!("Failed to hear the Core: {}", e)
            }
        }
    }
}
