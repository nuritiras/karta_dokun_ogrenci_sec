# Pardus ETAP 23 İçin Flutter ile "Kartla Öğrenci Seç" Uygulaması

"Kapalı Kartlar" (Memory Game mantığı), dokunmatik ekranlı etkileşimli tahtalarda (ETAP) öğrencilerin fiziksel olarak tahtaya kalkıp etkileşime girmesi için en heyecan verici yöntemlerden biridir. Flutter'ın animasyon yetenekleri bu "takla atma" (flip) efekti için biçilmiş kaftandır.

Pardus ETAP 23 üzerinde çalışacak, dokunmatik uyumlu ve Linux masaüstü çıktısı alabileceğin "Şanslı Kartlar" uygulaması için adım adım eğitim makalesini aşağıda hazırladım.

## Bu tasarımda:

Dinamik Izgara: Sınıfta kaç öğrenci varsa (veya Excel'den kaç kişi geldiyse), ekranı otomatik olarak onlara böler.

3D Animasyon: Karta dokunulduğunda kart gerçekçi bir şekilde (Y ekseninde) döner.

Gizem: Kartların arkası "soru işareti" veya renkli desenlidir.

Ses: Kart çevirme sesi ("Whoosh") ve isim açılınca alkış sesi.

İşte "Kapalı Kartlar" modu için hazırladığım tam kod (lib/main.dart):
<img width="1600" height="900" alt="image" src="https://github.com/user-attachments/assets/9aadbbaf-a5bc-4fb4-bc05-0d839389ef22" />
