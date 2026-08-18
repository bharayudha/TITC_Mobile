<?php

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

class TITC_Activity_Hooks {
    
    private $fcm_sender;

    public function __construct() {
        $this->fcm_sender = new TITC_FCM_Sender();
        
        // Hook into Fluent Community notification created event.
        // NOTE: Please ensure this is the exact hook used by Fluent Community. 
        // It might be 'fluent_community/notification_created' or similar.
        add_action('fluent_community/notification_created', array($this, 'on_notification_created'), 10, 2);
    }

    /**
     * @param array|object $notification The notification data object/array
     * @param int $user_id The recipient user ID
     */
    public function on_notification_created($notification, $user_id) {
        // Prepare title and body based on notification data.
        // You might need to adjust the keys ($notification->title vs $notification['title']) 
        // based on the actual object structure returned by Fluent Community.
        
        $title = "Notifikasi Baru dari TITC";
        $body = "Anda memiliki pesan atau aktivitas baru.";
        
        // Example parsing (adjust based on FCOM data structure):
        if (is_object($notification)) {
            $title = isset($notification->subject) ? $notification->subject : $title;
            $body = isset($notification->content) ? wp_strip_all_tags($notification->content) : $body;
        } elseif (is_array($notification)) {
            $title = isset($notification['subject']) ? $notification['subject'] : $title;
            $body = isset($notification['content']) ? wp_strip_all_tags($notification['content']) : $body;
        }

        // Additional data payload (can be used to deep link in the Flutter app)
        $data = [
            'type' => 'fcom_notification'
        ];

        $this->fcm_sender->send_notification($user_id, $title, $body, $data);
    }
}
