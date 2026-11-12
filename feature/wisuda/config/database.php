<?php
$host = 'localhost';
$dbname = 'si_kampus_db';
$username = 'root'; // Ganti dengan username database Anda
$password = '';     // Ganti dengan password database Anda

try {
    // Membuat instance PDO baru
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $username, $password);
    
    // Mengatur mode error PDO ke Exception agar error mudah dideteksi
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Mengatur default fetch mode ke associative array (opsional tapi disarankan)
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

    // Pesan sukses (bisa dihapus jika sudah digunakan di file lain)
    //echo "Koneksi ke database $dbname berhasil!";

} catch (PDOException $e) {
    // Tangkap error jika koneksi gagal
    die("Koneksi database gagal: " . $e->getMessage());
}
?>