<?php

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

class TITC_Activity_Hooks {
    
    private $fcm_sender;

    public function __construct() {
        $this->fcm_sender = new TITC_FCM_Sender();
        
        // Gunakan filter REST API bawaan WordPress untuk menyadap setiap kali ada aktivitas sukses
        // di endpoint Fluent Community. Ini lebih akurat dan "tahan banting" daripada menebak nama hook internal FCOM.
        add_filter('rest_request_after_callbacks', array($this, 'intercept_rest_requests'), 10, 3);
    }

    /**
     * Menyadap response REST API tepat sebelum dikembalikan ke user.
     */
    public function intercept_rest_requests($response, $handler, $request) {
        // Abaikan jika request gagal (error atau status code >= 300)
        if (is_wp_error($response) || $response->get_status() >= 300) {
            return $response;
        }

        $method = $request->get_method();
        $route = $request->get_route();

        // 1. Deteksi aksi "Follow User": POST /fluent-community/v2/profile/{username}/follow
        if ($method === 'POST' && preg_match('#^/fluent-community/v2/profile/([^/]+)/follow$#', $route, $matches)) {
            $followed_username = $matches[1];
            $followed_user = get_user_by('login', $followed_username);
            
            if ($followed_user) {
                // Ambil data orang yang sedang menge-klik tombol follow (user saat ini)
                $current_user = wp_get_current_user();
                $follower_name = !empty($current_user->display_name) ? $current_user->display_name : $current_user->user_login;
                
                // Kirim notifikasi ke HP orang yang di-follow
                $this->fcm_sender->send_notification(
                    $followed_user->ID, 
                    "Pengikut Baru \u{1F389}", 
                    "{$follower_name} sekarang mengikuti Anda di TITC.", 
                    ['type' => 'new_follower', 'follower_username' => $current_user->user_login]
                );
            }
        }

        // 2. Deteksi aksi "Post Feed Baru": POST /fluent-community/v2/feeds
        // (Berlaku untuk pembuatan feed global maupun di dalam space jika route-nya sama)
        if ($method === 'POST' && preg_match('#^/fluent-community/v2/feeds$#', $route, $matches)) {
            $current_user = wp_get_current_user();
            $author_name = !empty($current_user->display_name) ? $current_user->display_name : $current_user->user_login;
            
            // Kita bisa mengekstrak isi feed dari request body jika ingin
            $params = $request->get_json_params();
            $content = isset($params['post_content']) ? wp_strip_all_tags($params['post_content']) : 'Ada postingan baru di komunitas.';
            if (mb_strlen($content) > 50) {
                $content = mb_substr($content, 0, 47) . '...';
            }
            
            $this->fcm_sender->send_notification_to_topic(
                'global_feeds', 
                "Post Baru dari {$author_name} \u{1F4E3}", 
                $content, 
                ['type' => 'new_feed']
            );
        }

        return $response;
    }
}
