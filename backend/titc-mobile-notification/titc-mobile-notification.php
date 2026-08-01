<?php
/**
 * Plugin Name: TITC Mobile Notification
 * Description: Plugin untuk menjembatani trigger notifikasi dari BuddyBoss/WordPress ke Firebase Cloud Messaging (FCM) untuk aplikasi mobile TITC.
 * Version: 1.0.0
 * Author: TITC Indonesia
 */

if ( ! defined( 'ABSPATH' ) ) {
    exit; // Exit if accessed directly
}

// Load dependencies
require_once plugin_dir_path( __FILE__ ) . 'includes/class-activity-hooks.php';
require_once plugin_dir_path( __FILE__ ) . 'includes/class-fcm-sender.php';
require_once plugin_dir_path( __FILE__ ) . 'includes/class-device-token.php';
require_once plugin_dir_path( __FILE__ ) . 'includes/class-settings.php';
require_once plugin_dir_path( __FILE__ ) . 'includes/class-rest-endpoints.php';

// Initialize the plugin
function titc_mobile_notification_init() {
    // Initialize classes here
}
add_action( 'plugins_loaded', 'titc_mobile_notification_init' );
