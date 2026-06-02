import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/glass_card.dart';

/// In-app wiki — short how-to articles per feature, written in plain Russian.
/// Triggered from Settings → Помощь.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: 'Помощь',
        subtitle: 'Инструкции по разделам',
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(PhosphorIconsBold.arrowLeft,
              color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 80,
          left: 16,
          right: 16,
          bottom: 40,
        ),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(14),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(AppConstants.prefsKeyOnboarded, false);
              if (!context.mounted) return;
              context.go('/onboarding');
            },
            child: Row(
              children: [
                Icon(PhosphorIconsDuotone.graduationCap,
                    color: AppColors.primaryGlow, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Показать обучение',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '5-шаговый интерактивный тур',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(PhosphorIconsRegular.caretRight,
                    color: AppColors.textTertiary, size: 16),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final section in _sections) _SectionTile(section: section),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Не нашли ответ? Напишите нам или посмотрите полную документацию.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section});
  final _HelpSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: section.color.withValues(alpha: 0.2),
              border: Border.all(
                color: section.color.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(section.icon, color: section.color, size: 20),
          ),
          title: Text(
            section.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            section.summary,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
          iconColor: AppColors.primaryGlow,
          collapsedIconColor: AppColors.textTertiary,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in section.entries) _EntryBlock(entry: entry),
          ],
        ),
      ),
    );
  }
}

class _EntryBlock extends StatelessWidget {
  const _EntryBlock({required this.entry});
  final _HelpEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.body,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSection {
  const _HelpSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.summary,
    required this.entries,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String summary;
  final List<_HelpEntry> entries;
}

class _HelpEntry {
  const _HelpEntry({required this.title, required this.body});
  final String title;
  final String body;
}

const _sections = <_HelpSection>[
  _HelpSection(
    icon: PhosphorIconsDuotone.compass,
    color: AppColors.primaryGlow,
    title: 'Карта и навигация',
    summary: 'Жесты, шкала, центрирование, компас',
    entries: [
      _HelpEntry(
        title: 'Жесты на карте',
        body:
            '• Один палец — панорамирование.\n'
            '• Два пальца — зум и поворот.\n'
            '• Долгий тап на пустом месте — поставить точку здесь.\n'
            '• Тап на POI — открыть детали. Тап на кластер — раскрыть.\n'
            '• Карта остаётся там, где вы её оставили — авто-возврат к местоположению убран, чтобы разметка кварталов и измерения не прерывались.',
      ),
      _HelpEntry(
        title: 'Шкала масштаба',
        body:
            'В левом нижнем углу, прямо над нижней нав-панелью. Учитывает широту (Web-Mercator). Двигается, чтобы не перекрывать FAB-колонку справа.',
      ),
      _HelpEntry(
        title: 'Центрирование на себе',
        body:
            'Кнопка-локация (правая колонка) — карта летит к вашей позиции. Тап ещё раз цепляет track-up: вся карта вращается под направление устройства. Третий тап отключает следование — камера снова свободна.',
      ),
      _HelpEntry(
        title: 'Слайдер прозрачности слоя',
        body:
            'Тап по чипу слоя в Quick Layers Bar открывает вертикальный слайдер на левом краю карты. При включённом «расширенном компасе» слайдер автоматически уезжает под бейдж, чтобы они не накладывались.',
      ),
      _HelpEntry(
        title: 'Навигация к точке',
        body:
            'Откройте точку → «Навигация». На карте появится пунктир-маршрут, стрелка-азимут с расстоянием, голосовые подсказки (если включены).',
      ),
    ],
  ),
  _HelpSection(
    icon: PhosphorIconsDuotone.compassRose,
    color: AppColors.accentRose,
    title: 'Компас',
    summary: 'Пилюля HUD, расширенный режим, полный экран',
    entries: [
      _HelpEntry(
        title: 'Где включить',
        body:
            'Настройки → Отображение → «Компас». Под ним — отдельный тоггл «Расширенный компас (с розой)»: добавляет мини-розу С/В/Ю/З под цифрами.',
      ),
      _HelpEntry(
        title: 'Пилюля HUD',
        body:
            'Сверху, рядом со скоростью и точностью: иконка + угол + сторона света («127° СВ»). Цифры в фиксированных слотах — пилюля не дёргается при изменении значения. Тап — открывает полноэкранный компас.',
      ),
      _HelpEntry(
        title: 'Расширенный режим',
        body:
            'Если включить «Расширенный компас», под HUD-пилюлями появляется отдельная карточка 124×134 с цифрами и крутящейся мини-розой (С/В/Ю/З + красная N-стрелка). Карточка фиксированно стоит на левом краю — другие пилюли никогда не сдвинут её с места.',
      ),
      _HelpEntry(
        title: 'Полноэкранный компас',
        body:
            'По тапу на пилюлю или карточку. Большая роза с делениями каждые 5°, цифры угла 56 px, сторона света словом, и панель GPS-данных: широта, долгота, высота, точность, скорость.',
      ),
      _HelpEntry(
        title: 'Track-up на карте',
        body:
            'Кнопка локации, второй тап — иконка становится голубым компасом, и вся карта вращается под ваше направление. Удобно при пешем перемещении.',
      ),
    ],
  ),
  _HelpSection(
    icon: PhosphorIconsDuotone.stack,
    color: AppColors.accentCyan,
    title: 'Карты и слои',
    summary: 'Каталог, регионы РФ, MBTiles, XYZ',
    entries: [
      _HelpEntry(
        title: 'Выбор базовой карты',
        body:
            'Кнопка слоёв (правая колонка) → раздел «Базовая карта». Схема (OSM), Спутник (Esri), Гибрид, Рельеф (OpenTopoMap), Тёмная (CartoDB).',
      ),
      _HelpEntry(
        title: 'Каталог пресетов',
        body:
            'Добавить слой → вкладка «Каталог». 100+ готовых карт: топографические, спутник, исторические (Шуберт, РККА, Генштаб, Менде), морские / глубины (GEBCO, Esri Ocean, OpenSeaMap, EMODnet, NOAA), погодные.',
      ),
      _HelpEntry(
        title: 'Регионы РФ и поиск',
        body:
            '75+ регионов с подготовленными границами: от Москвы до Камчатки, а также отдельные водоёмы (Байкал, Ладога, Онега, Рыбинское, Селигер, Телецкое). Строка поиска ищет по имени и описанию — «Воронеж», «Карелия», «глубины».',
      ),
      _HelpEntry(
        title: 'Offline-загрузка карт',
        body:
            'На карточке региона — «Скачать для offline». Выберите диапазон зумов, оцените размер, запускайте. Приложением можно пользоваться во время скачивания — прогресс виден в мини-индикаторе и в Настройки → Загрузки карт.',
      ),
      _HelpEntry(
        title: 'Импорт MBTiles и XYZ',
        body:
            'Слои → «Добавить» → «Из файла» (для .mbtiles) или «По ссылке» (для своих XYZ-серверов с {z}/{x}/{y}). Растровые сканы (TIFF / JPG / PNG / JNX) — см. отдельный раздел «Растровые сканы».',
      ),
      _HelpEntry(
        title: 'Quick Layers Bar и прозрачность',
        body:
            'Чипы видимых слоёв сверху карты. Тап — показать / скрыть, повторный тап — открыть вертикальный slider прозрачности (на левом краю). Долгий тап — расширенное меню с переименованием и удалением.',
      ),
    ],
  ),
  _HelpSection(
    icon: PhosphorIconsDuotone.image,
    color: AppColors.accentViolet,
    title: 'Растровые сканы',
    summary: 'TIFF, JPG, PNG, JNX с авто-привязкой',
    entries: [
      _HelpEntry(
        title: 'Что поддерживается',
        body:
            '• .tif / .tiff — с сайдкаром .tfw, .tfwx, .wld или .aux.xml.\n'
            '• .jpg / .jpeg — с сайдкаром .jgw, .jgwx, .wld или .aux.xml.\n'
            '• .png — с сайдкаром .pgw, .wld или .aux.xml.\n'
            '• .jnx — Garmin BirdsEye (v3, без шифрования). Координаты внутри файла, сайдкар не нужен.',
      ),
      _HelpEntry(
        title: 'Где импортировать',
        body:
            'Слои → «Добавить» → «Из файла». Откроется системный диалог Android. Скан можно также добавить через «Привязка» — там тот же flow + ручная корректировка положения по углам.',
      ),
      _HelpEntry(
        title: 'Главное правило на Android',
        body:
            'Выделяйте растр И сайдкар ОДНОВРЕМЕННО (долгое нажатие → отметить оба файла). Из-за санбокса Scoped Storage Android передаёт в приложение только то, что вы реально выделили. Если возьмёте только .tif — соседний .tfw не доедет, и скан ляжет мимо координат.',
      ),
      _HelpEntry(
        title: 'Какой сайдкар выбирать',
        body:
            'Основной — .tfw / .tfwx (TIFF), .jgw / .jgwx (JPEG), .pgw (PNG). Файл .aux.xml — запасной: в нём часто только статистика без координат. Если приложение покажет «Файлы привязки выбраны, но разобрать их не удалось» — попробуйте .jgw / .tfw вместо .aux.xml.',
      ),
      _HelpEntry(
        title: 'JNX (Garmin BirdsEye)',
        body:
            'Просто выберите .jnx — координаты в файле. Приложение разберёт заголовок, найдёт самый детальный уровень, сохранит каждый JPEG-тайл с собственными bounds. Поддерживается v3 (без шифрования). v4 — пока нет, конвертируйте через GPSBabel / JNXlib в TIFF.',
      ),
      _HelpEntry(
        title: 'Поддерживаемые проекции',
        body:
            'WGS84 (EPSG:4326, градусы) и Web Mercator (EPSG:3857, метры) — определяются автоматически по диапазону координат. UTM, Гаусс-Крюгер и прочие метрические системы — попросит перепривязать в QGIS («Сохранить как → CRS: EPSG:4326»).',
      ),
      _HelpEntry(
        title: 'Большие сканы (>2048 px)',
        body:
            'Автоматически нарезаются на тайлы 2048×2048 при импорте — иначе Android-GPU тихо даун-семплит крупный растр до 4096 и теряет детализацию. После нарезки скан рендерится резко на любом зуме. На слабых устройствах импорт может занять до минуты — увидите спиннер «Разбираю скан…».',
      ),
      _HelpEntry(
        title: 'Привязка вручную',
        body:
            'Если у файла нет сайдкара или его не удаётся разобрать — слой ляжет в центр экрана, и появятся 4 угловых значка-маркера + центральный значок перемещения. Двигайте, тяните за углы, поворачивайте — затем «Сохранить».',
      ),
      _HelpEntry(
        title: 'Что делать с десятичными запятыми',
        body:
            'Если QGIS экспортирует .tfw с числами вида «4,12...» (русская локаль), приложение их понимает — десятичный разделитель определяется автоматически. Перепривязывать не нужно.',
      ),
    ],
  ),
  _HelpSection(
    icon: PhosphorIconsDuotone.mapPin,
    color: AppColors.accentAmber,
    title: 'Точки и объекты',
    summary: 'Создание, категории, фото и аудио',
    entries: [
      _HelpEntry(
        title: 'Создание точки',
        body:
            '3 способа:\n'
            '• Долгий тап по карте → «Точка здесь».\n'
            '• Кнопка-мишень (правая колонка).\n'
            '• Встряхивание телефона (если включено в настройках).',
      ),
      _HelpEntry(
        title: 'Категории и иконки',
        body:
            '8 категорий: Рыбалка, Охота, Туризм, Грибы/ягоды, Поиск, Инфраструктура, Опасности, Прочее. Каждый вид рыбы или дичи имеет свой цвет — различимы даже из далека.',
      ),
      _HelpEntry(
        title: 'Фото и аудио-заметки',
        body:
            'На экране новой точки — кнопка-микрофон рядом с названием записывает аудио (тап → идёт запись, тап → стоп). Фото — до 10 шт. через камеру или галерею.',
      ),
      _HelpEntry(
        title: 'Редактирование',
        body:
            'Откройте точку → кнопка-карандаш → все поля заполнены, меняйте имя, иконку, заметку, избранное.',
      ),
      _HelpEntry(
        title: 'Показать на карте',
        body:
            'В списке точек — круг с крестом справа от каждой строки. Тап → карта летит к точке (зум 17).',
      ),
    ],
  ),
  _HelpSection(
    icon: PhosphorIconsDuotone.polygon,
    color: AppColors.accentRose,
    title: 'Измерение и зоны',
    summary: 'Расстояние, площадь, кварталы',
    entries: [
      _HelpEntry(
        title: 'Измерить расстояние',
        body:
            'Кнопка-линейка на карте → выберите «Расстояние» → тапайте по карте. Сверху появится панель с общей длиной и сегментами.',
      ),
      _HelpEntry(
        title: 'Измерить площадь',
        body:
            'Линейка → «Площадь». Обведите замкнутый полигон — площадь и периметр в реальном времени. Единицы: м², га, км².',
      ),
      _HelpEntry(
        title: 'Интерактивные вершины',
        body:
            '• Тап на вершину — переименовать («Северный угол») или удалить.\n'
            '• Долгое нажатие + перетаскивание — двигать вершину.',
      ),
      _HelpEntry(
        title: 'Сохранить как зону',
        body:
            'Кнопка-дискета в панели измерения → введите имя → выберите тип (Охотничье угодье, Лесной квартал, Аквазона, Грибное место, Запретная зона, Моя зона) → «Сохранить».',
      ),
      _HelpEntry(
        title: 'Редактирование зоны',
        body:
            'Треки → вкладка «Зоны» → тап → «Редактировать». Вершины загрузятся в режим измерения, правьте их, затем «Перезаписать» — существующая зона обновится по месту.',
      ),
    ],
  ),
  _HelpSection(
    icon: PhosphorIconsDuotone.path,
    color: AppColors.primaryBright,
    title: 'Треки и запись',
    summary: 'Запись, фон, фильтр Калмана',
    entries: [
      _HelpEntry(
        title: 'Старт / стоп трека',
        body:
            'Кнопка-запись в правой колонке. При старте запрашивается разрешение «Всегда» на локацию (нужно для фона). Стоп — той же кнопкой или из бейджа записи внизу карты.',
      ),
      _HelpEntry(
        title: 'Работа в фоне',
        body:
            'После старта появляется foreground-уведомление «Запись трека активна». Запись не прекращается при заблокированном экране и сворачивании приложения. В уведомлении настраивается, что показывать (время, дистанция, скорость, кол-во точек) — Настройки → Уведомление о записи.',
      ),
      _HelpEntry(
        title: 'Точность в РФ (глушилки)',
        body:
            'GPS-фиксы проходят через фильтр Калмана: сглаживание по координатам + отбрасывание выбросов > 150 м. Полезно в городах и рядом с режимными объектами.',
      ),
      _HelpEntry(
        title: 'Камера во время записи',
        body:
            'Авто-возврат к местоположению по таймауту убран. Когда пишете трек, можете свободно перемещать карту в нужное место (отметить квартал, измерить расстояние) — она там и останется. Чтобы вернуться к себе — кнопка локации.',
      ),
      _HelpEntry(
        title: 'Экспорт трека',
        body:
            'Настройки → Импорт / экспорт GPX → «Только треки» или «Всё в один GPX». Готовый .gpx шарится через системный диалог.',
      ),
      _HelpEntry(
        title: 'Где хранятся треки',
        body:
            'Внутри приложения, в SharedPreferences (ключ tracks_v1). Один трек — от ~36 КБ (короткая прогулка) до ~280 КБ (8-часовой выход). Для переноса используйте Резервную копию (.chaliy) или GPX-экспорт.',
      ),
    ],
  ),
  _HelpSection(
    icon: PhosphorIconsDuotone.swap,
    color: AppColors.accentAmber,
    title: 'Импорт и экспорт (вектор)',
    summary: 'GPX / KML / KMZ / GeoJSON',
    entries: [
      _HelpEntry(
        title: 'Что поддерживается',
        body:
            '• .gpx — Garmin, Strava, OSM, OsmAnd.\n'
            '• .kml, .kmz — Google Earth, Google My Maps, Яндекс Избранное, Maps.me, OrganicMaps.\n'
            '• .geojson, .json — QGIS, все ГИС-приложения.\n\n'
            'Растровые сканы (.tif / .jpg / .png / .jnx) — отдельный раздел «Растровые сканы».',
      ),
      _HelpEntry(
        title: 'Импорт из QGIS',
        body:
            '• Точки / линии / полигоны: Layer → Export → Save Features As → GeoJSON (или GPX).\n'
            '• Растровые карты: Processing → «Generate XYZ tiles (MBTiles)» → импортируйте .mbtiles как offline-слой.\n'
            '• Сканы листов: экспорт в TIFF / JPEG → импорт через «Из файла» с world-сайдкаром.',
      ),
      _HelpEntry(
        title: 'Откуда брать файлы',
        body:
            '• Google Earth / My Maps: меню слоя → «Экспорт» → KML.\n'
            '• Яндекс.Карты: Избранное → Поделиться → KML.\n'
            '• Maps.me / OrganicMaps: закладки → Поделиться → KML / KMZ.\n'
            '• Garmin: активность → Экспорт → Original GPX.\n'
            '• Strava: тренировка → «…» → Export GPX.',
      ),
      _HelpEntry(
        title: 'Резервная копия .chaliy',
        body:
            'Настройки → Резервная копия → Создать. На выходе зашифрованный (AES-256, ваш пароль) ZIP с точками, треками, маршрутами, зонами, слоями и настройками. Можно перенести на другое устройство и развернуть тем же паролем. Фото / аудио / .mbtiles в бэкап не входят (слишком тяжело).',
      ),
    ],
  ),
  _HelpSection(
    icon: PhosphorIconsDuotone.shieldCheck,
    color: AppColors.info,
    title: 'Безопасность и приватность',
    summary: 'Шифрование, биометрия, офлайн',
    entries: [
      _HelpEntry(
        title: 'Всё локально по умолчанию',
        body:
            'Точки, треки, зоны, карты — всё хранится на устройстве. Приложение не требует регистрации и не шлёт координаты в облако без вашего согласия. В трафик уходят только запросы тайлов выбранных карт.',
      ),
      _HelpEntry(
        title: 'Биометрическая блокировка',
        body:
            'Настройки → Безопасность → «Блокировать приложение». Каждый запуск — Face ID / отпечаток / PIN устройства. После 2 неудачных попыток — аварийный выход (срабатывает кнопкой «Эвакуация»).',
      ),
      _HelpEntry(
        title: 'Шифрование данных',
        body:
            'AES-256-CBC для секретных категорий и резервных копий. Ключ деривируется из пользовательского пароля через SHA-256 × 10 000 итераций + соль. Никакие пароли в открытом виде на диск не пишутся.',
      ),
      _HelpEntry(
        title: 'Разрешения',
        body:
            'Локация «всегда» — только при старте записи трека. Камера / микрофон / медиа — только при создании точки с фото / аудио. Биометрия — только при включении блокировки.',
      ),
    ],
  ),
];
