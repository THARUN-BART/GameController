use receiver::pairing::{PairingManager, APP_IDENTIFIER, PROTOCOL_VERSION};

#[test]
fn test_qr_payload_generation() {
    let host = "192.168.1.100".to_string();
    let port = 8080;
    let name = "TEST-PC".to_string();

    let mgr = PairingManager::new(host.clone(), port, name.clone());
    let payload = mgr.current_payload();

    assert_eq!(payload.v, PROTOCOL_VERSION);
    assert_eq!(payload.app, APP_IDENTIFIER);
    assert_eq!(payload.host, host);
    assert_eq!(payload.port, port);
    assert_eq!(payload.name, name);
    assert_eq!(payload.proto, "ws");
    assert!(!payload.token.is_empty());
    assert!(payload.exp > 0);
}

#[test]
fn test_token_validation() {
    let mgr = PairingManager::new("192.168.1.100".to_string(), 8080, "TEST-PC".to_string());
    let token = mgr.current_token().to_string();

    // Valid token succeeds
    assert!(mgr.validate_token(&token).is_ok());

    // Wrong token fails
    assert!(mgr.validate_token("incorrect-token-value").is_err());
}

#[test]
fn test_qr_terminal_rendering() {
    let mgr = PairingManager::new("192.168.1.100".to_string(), 8080, "TEST-PC".to_string());
    let qr_art = mgr.render_qr_terminal().expect("QR rendering should succeed");

    assert!(!qr_art.is_empty());
    assert!(qr_art.lines().count() > 10);
}
