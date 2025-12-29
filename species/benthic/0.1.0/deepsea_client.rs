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

    /// Rez a primitive on login
    #[arg(long = "rez", default_value_t = false)]
    rez: bool,

    #[arg(long = "timeout", default_value_t = 0)]
    timeout: u64,
}

// Commands from stdin
enum Command {
    Chat(String),
    Sleep(f64),
    WhoAmI,
    Who,
    Where,
    When,
    SubjectiveWhy,
    SubjectiveBecause(String),
    SubjectiveLook,
    SubjectiveGoto(String),
    Pos(String),
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

    log_encounter("Login", "Start", &format!("URI: {}, User: {} {}", args.uri, args.first_name, args.last_name));

    let (sender, receiver) = unbounded();
    let (cmd_sender, cmd_receiver) = unbounded();

    // Start stdin listener
    std::thread::spawn(move || {
        println!("benthic_deepsea_client REPL. Commands: SLEEP, WHOAMI, WHO, WHERE, WHEN, SUBJECTIVE_WHY, SUBJECTIVE_BECAUSE, SUBJECTIVE_LOOK, SUBJECTIVE_GOTO, POS, CHAT, LOGOUT, EXIT");
        let stdin = io::stdin();
        let handle = stdin.lock();
        for line in handle.lines() {
            if let Ok(l) = line {
                let l = l.trim();
                if l.is_empty() { continue; }
                // log_encounter("STDIN", "COMMAND", l); // Optional: log commands? mimic doesn't seem to log raw input

                if l.starts_with("CHAT ") {
                    let msg = l[5..].to_string();
                    let _ = cmd_sender.send(Command::Chat(msg));
                } else if l.starts_with("SLEEP ") {
                    if let Ok(secs) = l[6..].parse::<f64>() {
                        let _ = cmd_sender.send(Command::Sleep(secs));
                    } else {
                        println!("Usage: SLEEP float_seconds");
                    }
                } else if l == "WHOAMI" {
                    let _ = cmd_sender.send(Command::WhoAmI);
                } else if l == "WHO" {
                    let _ = cmd_sender.send(Command::Who);
                } else if l == "WHERE" {
                    let _ = cmd_sender.send(Command::Where);
                } else if l == "WHEN" {
                    let _ = cmd_sender.send(Command::When);
                } else if l == "SUBJECTIVE_WHY" {
                    let _ = cmd_sender.send(Command::SubjectiveWhy);
                } else if l.starts_with("SUBJECTIVE_BECAUSE ") {
                    let reason = l[19..].to_string();
                    let _ = cmd_sender.send(Command::SubjectiveBecause(reason));
                } else if l == "SUBJECTIVE_LOOK" {
                    let _ = cmd_sender.send(Command::SubjectiveLook);
                } else if l.starts_with("SUBJECTIVE_GOTO ") {
                    let dest = l[16..].to_string();
                    let _ = cmd_sender.send(Command::SubjectiveGoto(dest));
                } else if l.starts_with("POS ") {
                    let dest = l[4..].to_string();
                    let _ = cmd_sender.send(Command::Pos(dest));
                } else if l == "LOGOUT" {
                    let _ = cmd_sender.send(Command::Logout);
                } else if l == "EXIT" {
                    let _ = cmd_sender.send(Command::Exit);
                } else {
                    println!("Unknown command: {}", l);
                }
            } else {
                // EOF logic
                // Ensure we signal exit if stdin closes
                let _ = cmd_sender.send(Command::Exit);
                break;
            }
        }
        let _ = cmd_sender.send(Command::Exit);
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
    let mut subjective_because = String::new();
    let mut current_first_name = String::new();
    let mut current_last_name = String::new();
    let mut wake_time: Option<std::time::Instant> = None;

    loop {
        // Handle Timeout
        if args.timeout > 0 && start_time.elapsed() > Duration::from_secs(args.timeout) {
             log_encounter("System", "Timeout", "Max run time reached.");
             break;
        }

        // Handle Sleep (non-blocking)
        if let Some(wt) = wake_time {
            if std::time::Instant::now() >= wt {
                wake_time = None;
                // Calculate actual sleep time?
                log_encounter("System", "Sleep", "Woke up");
            } else {
                // Yield and continue loop
                sleep(Duration::from_millis(50));
                continue;
            }
        }

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
                 Command::Sleep(secs) => {
                     wake_time = Some(std::time::Instant::now() + Duration::from_millis((secs * 1000.0) as u64));
                     // sleep(Duration::from_millis((secs * 1000.0) as u64));
                     // log_encounter("System", "Sleep", &format!("Slept {}s", secs));
                 },
                 Command::WhoAmI => {
                     if logged_in {
                         log_encounter("Self", "Identity", &format!("Name: {} {}", current_first_name, current_last_name));
                     } else {
                         println!("Not connected.");
                     }
                 },
                 Command::Who => {
                     log_encounter("System", "NotImplemented", "WHO is not yet implemented in Benthic.");
                 },
                 Command::Where => {
                     log_encounter("System", "NotImplemented", "WHERE is not yet implemented in Benthic.");
                 },
                 Command::When => {
                     log_encounter("System", "NotImplemented", "WHEN is not yet implemented in Benthic.");
                 },
                 Command::SubjectiveWhy => {
                     log_encounter("Cognition", "Why", &subjective_because);
                 },
                 Command::SubjectiveBecause(reason) => {
                     subjective_because = reason;
                     log_encounter("Cognition", "Because", "Updated");
                 },
                 Command::SubjectiveLook => {
                     log_encounter("System", "NotImplemented", "SUBJECTIVE_LOOK is not yet implemented in Benthic.");
                 },
                 Command::SubjectiveGoto(_) => {
                     log_encounter("System", "NotImplemented", "SUBJECTIVE_GOTO is not yet implemented in Benthic.");
                 },
                 Command::Pos(_) => {
                     log_encounter("System", "NotImplemented", "POS is not yet implemented in Benthic.");
                 },
                 Command::Logout => {
                     log_encounter("Logout", "REPL", "Director requested logout");
                     return;
                 },
                 Command::Exit => {
                     log_encounter("Exit", "REPL", "Director requested exit");
                     std::process::exit(0);
                 }
             }
        }

        // Non-blocking check for messages
        match receiver.recv_timeout(Duration::from_millis(50)) {
            Ok(event) => {
                if !matches!(event, UIMessage::LandUpdate(_)) {
                    last_message_was_land_update = false;
                }

                match event {
                    UIMessage::LoginResponse(response) => {
                         current_first_name = response.firstname.clone();
                         current_last_name = response.lastname.clone();
                         log_encounter("Login", "Success", &format!("Agent: {} {}", current_first_name, current_last_name));
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
