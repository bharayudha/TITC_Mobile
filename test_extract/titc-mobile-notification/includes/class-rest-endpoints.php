<?php

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

class TITC_REST_Endpoints {
    
    public function __construct() {
        add_action('rest_api_init', array($this, 'register_endpoints'));
    }

    public function register_endpoints() {
        register_rest_route('titc-mobile/v1', '/device-token', array(
            'methods' => 'POST',
            'callback' => array($this, 'save_device_token'),
            'permission_callback' => array($this, 'check_user_permission'),
        ));
    }

    public function check_user_permission() {
        // Since Flutter uses cookies or JWT, we assume standard WordPress auth applies.
        return is_user_logged_in();
    }

    public function save_device_token($request) {
        $user_id = get_current_user_id();
        $params = $request->get_json_params();
        
        if (empty($params['token'])) {
            return new WP_Error('missing_token', 'Device token is missing', array('status' => 400));
        }

        $token = sanitize_text_field($params['token']);
        
        // Save the token to the user meta
        update_user_meta($user_id, 'titc_fcm_device_token', $token);

        return rest_ensure_response(array(
            'success' => true,
            'message' => 'Token saved successfully',
            'token' => $token
        ));
    }
}
