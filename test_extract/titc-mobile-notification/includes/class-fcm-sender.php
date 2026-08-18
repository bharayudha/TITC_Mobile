<?php

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

class TITC_FCM_Sender {
    
    private $service_account_path;
    
    public function __construct() {
        // Path to the service account JSON file. You should place the json file in the plugin directory.
        $this->service_account_path = plugin_dir_path(dirname(__FILE__)) . 'service-account.json';
    }

    private function get_access_token() {
        if (!file_exists($this->service_account_path)) {
            error_log('TITC FCM: service-account.json not found');
            return null;
        }

        $key_data = json_decode(file_get_contents($this->service_account_path), true);
        if (!$key_data) return null;

        $header = json_encode(['alg' => 'RS256', 'typ' => 'JWT']);
        $now = time();
        $claim = json_encode([
            'iss' => $key_data['client_email'],
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud' => $key_data['token_uri'],
            'exp' => $now + 3600,
            'iat' => $now
        ]);

        $base64_header = $this->base64url_encode($header);
        $base64_claim = $this->base64url_encode($claim);
        $signature_input = $base64_header . '.' . $base64_claim;
        
        $signature = '';
        openssl_sign($signature_input, $signature, $key_data['private_key'], 'sha256WithRSAEncryption');
        $base64_signature = $this->base64url_encode($signature);
        
        $jwt = $signature_input . '.' . $base64_signature;
        
        $response = wp_remote_post($key_data['token_uri'], [
            'body' => [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt
            ]
        ]);
        
        if (is_wp_error($response)) {
            error_log('TITC FCM Token Error: ' . $response->get_error_message());
            return null;
        }

        $body = json_decode(wp_remote_retrieve_body($response), true);
        return $body['access_token'] ?? null;
    }

    private function base64url_encode($data) {
        return str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($data));
    }

    public function send_notification($user_id, $title, $body, $data = []) {
        $token = get_user_meta($user_id, 'titc_fcm_device_token', true);
        if (empty($token)) {
            return false;
        }

        $access_token = $this->get_access_token();
        if (!$access_token) {
            return false;
        }

        $key_data = json_decode(file_get_contents($this->service_account_path), true);
        $project_id = $key_data['project_id'];
        
        $fcm_url = "https://fcm.googleapis.com/v1/projects/{$project_id}/messages:send";

        $message = [
            'message' => [
                'token' => $token,
                'notification' => [
                    'title' => $title,
                    'body' => $body
                ],
                'data' => $data
            ]
        ];

        $response = wp_remote_post($fcm_url, [
            'headers' => [
                'Authorization' => 'Bearer ' . $access_token,
                'Content-Type'  => 'application/json'
            ],
            'body' => json_encode($message)
        ]);

        if (is_wp_error($response)) {
            error_log('TITC FCM Send Error: ' . $response->get_error_message());
            return false;
        }

        return true;
    }
}
