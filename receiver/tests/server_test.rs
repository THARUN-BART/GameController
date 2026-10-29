use futures_util::{SinkExt, StreamExt};
use receiver::protocol::{ClientMessage, ServerMessage, PROTOCOL_VERSION};
use receiver::server::ReceiverServer;
use std::time::Duration;
use tokio::net::TcpListener;
use tokio_tungstenite::connect_async;
use tokio_tungstenite::tungstenite::Message;

#[tokio::test]
async fn test_successful_pairing_and_ping_pong() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    let (server, pairing_mgr, controller_st, _) = ReceiverServer::new(addr.port());

    let token = {
        let mgr = pairing_mgr.lock().await;
        mgr.current_token().to_string()
    };

    tokio::spawn(async move {
        let _ = server.run_on_listener(listener).await;
    });

    // Connect client
    let ws_url = format!("ws://{}:{}", addr.ip(), addr.port());
    let (ws_stream, _) = connect_async(&ws_url).await.expect("Failed to connect");
    let (mut write, mut read) = ws_stream.split();

    // 1. Send valid Pair handshake
    let pair_msg = ClientMessage::Pair {
        token: token.clone(),
        client_name: "Test-Phone".to_string(),
        client_version: PROTOCOL_VERSION,
    };
    write
        .send(Message::Text(serde_json::to_string(&pair_msg).unwrap().into()))
        .await
        .unwrap();

    // 2. Expect PairAck with success: true
    let resp = read.next().await.unwrap().unwrap();
    if let Message::Text(text) = resp {
        let parsed: ServerMessage = serde_json::from_str(&text).unwrap();
        match parsed {
            ServerMessage::PairAck { success, version, .. } => {
                assert!(success, "Expected successful pairing ack");
                assert_eq!(version, PROTOCOL_VERSION);
            }
            other => panic!("Unexpected response: {:?}", other),
        }
    } else {
        panic!("Expected text message");
    }

    // 3. Send Ping
    let ping_msg = ClientMessage::Ping { ts: 1234567890 };
    write
        .send(Message::Text(serde_json::to_string(&ping_msg).unwrap().into()))
        .await
        .unwrap();

    // 4. Expect Pong
    let pong_resp = read.next().await.unwrap().unwrap();
    if let Message::Text(text) = pong_resp {
        let parsed: ServerMessage = serde_json::from_str(&text).unwrap();
        match parsed {
            ServerMessage::Pong { client_ts, server_ts } => {
                assert_eq!(client_ts, 1234567890);
                assert!(server_ts > 0);
            }
            other => panic!("Unexpected response: {:?}", other),
        }
    } else {
        panic!("Expected text message for pong");
    }

    // 5. Send Input
    let input_msg = ClientMessage::Input {
        seq: 1,
        ts: 1234567891,
        left_stick: Some(receiver::protocol::StickPayload { x: 0.5, y: -0.5 }),
        right_stick: None,
        buttons: vec!["CROSS".to_string(), "SQUARE".to_string()],
    };
    write
        .send(Message::Text(serde_json::to_string(&input_msg).unwrap().into()))
        .await
        .unwrap();

    tokio::time::sleep(Duration::from_millis(50)).await;

    {
        let st = controller_st.lock().await;
        assert_eq!(st.sequence_number, 1);
        assert!((st.left_stick_x - 0.5).abs() < 1e-4);
        assert!((st.left_stick_y - (-0.5)).abs() < 1e-4);
        assert!(st.pressed_buttons.contains("CROSS"));
        assert!(st.pressed_buttons.contains("SQUARE"));
    }

    // 6. Disconnect
    let disc = ClientMessage::Disconnect {
        reason: Some("test_complete".to_string()),
    };
    write
        .send(Message::Text(serde_json::to_string(&disc).unwrap().into()))
        .await
        .unwrap();

    tokio::time::sleep(Duration::from_millis(50)).await;

    // Verify inputs reset to neutral
    {
        let st = controller_st.lock().await;
        assert_eq!(st.left_stick_x, 0.0);
        assert_eq!(st.left_stick_y, 0.0);
        assert!(st.pressed_buttons.is_empty());
    }
}

#[tokio::test]
async fn test_pairing_rejected_with_invalid_token() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    let (server, _, _, _) = ReceiverServer::new(addr.port());

    tokio::spawn(async move {
        let _ = server.run_on_listener(listener).await;
    });

    let ws_url = format!("ws://{}:{}", addr.ip(), addr.port());
    let (ws_stream, _) = connect_async(&ws_url).await.expect("Failed to connect");
    let (mut write, mut read) = ws_stream.split();

    // Send invalid token
    let pair_msg = ClientMessage::Pair {
        token: "completely_fake_invalid_token_999".to_string(),
        client_name: "Intruder".to_string(),
        client_version: PROTOCOL_VERSION,
    };
    write
        .send(Message::Text(serde_json::to_string(&pair_msg).unwrap().into()))
        .await
        .unwrap();

    let resp = read.next().await.unwrap().unwrap();
    if let Message::Text(text) = resp {
        let parsed: ServerMessage = serde_json::from_str(&text).unwrap();
        match parsed {
            ServerMessage::PairAck { success, message, .. } => {
                assert!(!success, "Pairing should have failed");
                assert!(message.contains("Invalid pairing token"));
            }
            other => panic!("Unexpected response: {:?}", other),
        }
    }

    // Ensure connection is closed by server
    let next = read.next().await;
    assert!(next.is_none() || matches!(next, Some(Ok(Message::Close(_)))));
}

#[tokio::test]
async fn test_unauthenticated_first_message_rejected() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    let (server, _, _, _) = ReceiverServer::new(addr.port());

    tokio::spawn(async move {
        let _ = server.run_on_listener(listener).await;
    });

    let ws_url = format!("ws://{}:{}", addr.ip(), addr.port());
    let (ws_stream, _) = connect_async(&ws_url).await.expect("Failed to connect");
    let (mut write, mut read) = ws_stream.split();

    // Send ping first instead of pair
    let ping_msg = ClientMessage::Ping { ts: 12345 };
    write
        .send(Message::Text(serde_json::to_string(&ping_msg).unwrap().into()))
        .await
        .unwrap();

    let resp = read.next().await.unwrap().unwrap();
    if let Message::Text(text) = resp {
        let parsed: ServerMessage = serde_json::from_str(&text).unwrap();
        match parsed {
            ServerMessage::Error { code, .. } => {
                assert_eq!(code, 401);
            }
            other => panic!("Expected 401 error, got: {:?}", other),
        }
    }

    // Ensure connection is terminated
    let next = read.next().await;
    assert!(next.is_none() || matches!(next, Some(Ok(Message::Close(_)))));
}

#[tokio::test]
async fn test_session_locking_and_reconnection() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    let (server, pairing_mgr, _, _) = ReceiverServer::new(addr.port());

    let token = {
        let mgr = pairing_mgr.lock().await;
        mgr.current_token().to_string()
    };

    tokio::spawn(async move {
        let _ = server.run_on_listener(listener).await;
    });

    let ws_url = format!("ws://{}:{}", addr.ip(), addr.port());

    // Client 1 connects and pairs
    let (ws1, _) = connect_async(&ws_url).await.unwrap();
    let (mut write1, mut read1) = ws1.split();
    let pair1 = ClientMessage::Pair {
        token: token.clone(),
        client_name: "Client-One".to_string(),
        client_version: PROTOCOL_VERSION,
    };
    write1.send(Message::Text(serde_json::to_string(&pair1).unwrap().into())).await.unwrap();
    let resp1 = read1.next().await.unwrap().unwrap();
    if let Message::Text(txt) = resp1 {
        let parsed: ServerMessage = serde_json::from_str(&txt).unwrap();
        assert!(matches!(parsed, ServerMessage::PairAck { success: true, .. }));
    }

    // Client 1 sends a ping to keep session alive
    let ping = ClientMessage::Ping { ts: 100 };
    write1.send(Message::Text(serde_json::to_string(&ping).unwrap().into())).await.unwrap();
    let _ = read1.next().await;

    // Disconnect Client 1 cleanly
    let disc = ClientMessage::Disconnect { reason: Some("done".to_string()) };
    write1.send(Message::Text(serde_json::to_string(&disc).unwrap().into())).await.unwrap();
    tokio::time::sleep(Duration::from_millis(50)).await;

    // Verify session was unlocked
    {
        let mgr = pairing_mgr.lock().await;
        assert!(!mgr.is_session_active(), "Session should be released after disconnect");
    }
}

#[tokio::test]
async fn test_inactivity_watchdog_neutralizes_state() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    let (server, pairing_mgr, controller_st, _) = ReceiverServer::new(addr.port());

    let token = {
        let mgr = pairing_mgr.lock().await;
        mgr.current_token().to_string()
    };

    tokio::spawn(async move {
        let _ = server.run_on_listener(listener).await;
    });

    let ws_url = format!("ws://{}:{}", addr.ip(), addr.port());
    let (ws_stream, _) = connect_async(&ws_url).await.unwrap();
    let (mut write, mut read) = ws_stream.split();

    // Authenticate
    let pair = ClientMessage::Pair {
        token,
        client_name: "Watchdog-Tester".to_string(),
        client_version: PROTOCOL_VERSION,
    };
    write.send(Message::Text(serde_json::to_string(&pair).unwrap().into())).await.unwrap();
    let _ = read.next().await;

    // Send active input (holding stick and triangle button)
    let input = ClientMessage::Input {
        seq: 1,
        ts: 1000,
        left_stick: Some(receiver::protocol::StickPayload { x: 0.9, y: 0.8 }),
        right_stick: None,
        buttons: vec!["TRIANGLE".to_string()],
    };
    write.send(Message::Text(serde_json::to_string(&input).unwrap().into())).await.unwrap();
    tokio::time::sleep(Duration::from_millis(50)).await;

    // Verify input applied
    {
        let st = controller_st.lock().await;
        assert!((st.left_stick_x - 0.9).abs() < 1e-4);
        assert!(st.pressed_buttons.contains("TRIANGLE"));
    }

    // Now sleep 4.2 seconds without sending any messages (triggering the 4-second watchdog)
    tokio::time::sleep(Duration::from_millis(4200)).await;

    // Verify watchdog triggered and neutralized inputs!
    {
        let st = controller_st.lock().await;
        assert_eq!(st.left_stick_x, 0.0, "Watchdog must zero stick X");
        assert_eq!(st.left_stick_y, 0.0, "Watchdog must zero stick Y");
        assert!(st.pressed_buttons.is_empty(), "Watchdog must release buttons");
    }

    // Clean up
    let _ = write.close().await;
}
