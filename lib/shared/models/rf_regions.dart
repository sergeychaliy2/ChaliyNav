import 'map_layer.dart';
import 'map_preset.dart';

/// Curated bounding boxes for Russian Federation: federal subjects, major
/// cities and notable water bodies. Tuned for offline raster-tile downloads
/// — bbox is intentionally a bit wider than the administrative boundary.
///
/// Values are rough — a 2-3 km padding is acceptable since tiles are aligned
/// to the Web-Mercator grid anyway. For precise admin boundaries, use OSM
/// relations (not the job of an offline downloader).
class RfRegions {
  RfRegions._();

  /// Returns full catalogue as MapPresets (kind = regionsRu), sorted
  /// alphabetically by name using locale-insensitive case-folding —
  /// Cyrillic sorts correctly (UTF-16 puts А-я in one contiguous block).
  static List<MapPreset> all() {
    final list = [
      for (final e in _entries)
        MapPreset(
          id: 'ru_${e.id}',
          name: e.name,
          category: MapPresetCategory.regionsRu,
          type: MapLayerType.tileUrl,
          source: e.isTerrain
              ? 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          description: e.description,
          attribution: e.isTerrain ? '© OpenTopoMap' : '© OpenStreetMap',
          maxZoom: e.isTerrain ? 17 : 19,
          region: PresetRegion(
            northLat: e.n,
            southLat: e.s,
            westLng: e.w,
            eastLng: e.e,
            recommendedMinZoom: e.zMin,
            recommendedMaxZoom: e.zMax,
          ),
        ),
    ]..sort((a, b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Search by name (case-insensitive substring). Results stay alphabetical.
  static List<MapPreset> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all();
    return all()
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q))
        .toList();
  }

  // Compact raw table — easier to scan / extend than 70 full MapPresets.
  static const List<_Entry> _entries = [
    // === Столицы и агломерации ===
    _Entry('moscow', 'Москва и область',
        'Агломерация МКАД-А107 + ближнее Подмосковье',
        56.2, 55.0, 36.5, 38.5, 10, 14),
    _Entry('spb', 'Санкт-Петербург и ЛО',
        'Финский залив, Всеволожск, Гатчина, Выборг',
        61.0, 58.8, 27.5, 33.5, 9, 13, isTerrain: true),
    _Entry('kazan', 'Казань и окрестности',
        'Татарстан, Куйбышевское водохранилище',
        56.5, 55.3, 48.5, 50.5, 9, 14),
    _Entry('nizhny', 'Нижний Новгород',
        'Волга + Ока, НиГРЭС, Богородск',
        57.2, 55.7, 43.0, 45.2, 9, 14),
    _Entry('ekb', 'Екатеринбург',
        'Свердловская обл., Чусовая, Исеть',
        58.5, 56.0, 59.0, 62.0, 9, 14, isTerrain: true),
    _Entry('novosib', 'Новосибирск',
        'Обь, Обское водохранилище, НСО',
        56.0, 53.5, 81.0, 85.0, 9, 13),
    _Entry('krasnoyarsk', 'Красноярск',
        'Енисей, Саяно-Шушенское вдхр, Столбы',
        58.0, 52.0, 88.0, 95.0, 8, 13, isTerrain: true),
    _Entry('rostov', 'Ростов-на-Дону',
        'Дон, Азов, Таганрог',
        48.5, 46.5, 38.5, 41.5, 9, 13),
    _Entry('krasnodar', 'Краснодар и край',
        'Кубань, Черное море, Сочи, Анапа',
        46.7, 43.3, 36.5, 41.5, 9, 13, isTerrain: true),
    _Entry('vladivostok', 'Владивосток и Приморье',
        'Японское море, Уссури, Находка',
        48.0, 42.5, 130.5, 136.0, 9, 13, isTerrain: true),

    // === Субъекты европейской части ===
    _Entry('voronezh', 'Воронеж и область',
        'Дон, Воронежское водохранилище',
        52.6, 49.5, 38.0, 43.0, 9, 13),
    _Entry('veliky_novgorod', 'Великий Новгород',
        'Ильмень, Волхов, Мста',
        59.3, 57.5, 29.5, 35.5, 9, 13, isTerrain: true),
    _Entry('pskov', 'Псков и область',
        'Псковское и Чудское озёра',
        59.0, 55.5, 27.0, 31.5, 9, 13, isTerrain: true),
    _Entry('smolensk', 'Смоленск',
        'Днепр, Угра, Соловьёва переправа',
        55.8, 53.5, 30.5, 35.5, 9, 13),
    _Entry('tver', 'Тверь и область',
        'Волга исток, Селигер, Вышний Волочёк',
        58.5, 55.8, 32.0, 38.0, 9, 13, isTerrain: true),
    _Entry('yaroslavl', 'Ярославль',
        'Волга, Рыбинское водохранилище',
        59.3, 57.0, 37.5, 41.5, 9, 13),
    _Entry('vladimir', 'Владимир + Суздаль',
        'Клязьма, Нерль, Золотое кольцо',
        56.8, 55.0, 38.8, 42.5, 9, 13),
    _Entry('ivanovo', 'Иваново',
        'Текстильный край, Тёза, Уводь',
        57.8, 56.2, 39.5, 43.0, 9, 13),
    _Entry('kaluga', 'Калуга',
        'Ока, Угра, Таруса',
        55.2, 53.2, 34.0, 37.5, 9, 13),
    _Entry('tula', 'Тула',
        'Упа, Плава, Куликово поле',
        54.8, 52.8, 35.5, 39.5, 9, 13),
    _Entry('ryazan', 'Рязань',
        'Ока, Пра, Мещёра',
        55.2, 53.3, 38.5, 43.0, 9, 13, isTerrain: true),
    _Entry('lipetsk', 'Липецк',
        'Дон, Воронеж, Матыра',
        53.8, 51.7, 37.5, 41.0, 9, 13),
    _Entry('tambov', 'Тамбов',
        'Цна, Ворона',
        54.0, 51.8, 40.0, 43.5, 9, 13),
    _Entry('kursk', 'Курск',
        'Сейм, Тускарь',
        52.7, 50.8, 34.5, 38.0, 9, 13),
    _Entry('belgorod', 'Белгород',
        'Северский Донец, Оскол',
        51.5, 49.8, 35.0, 39.0, 9, 13),
    _Entry('orel', 'Орёл',
        'Ока, Зуша',
        53.8, 52.0, 34.5, 38.5, 9, 13),
    _Entry('bryansk', 'Брянск',
        'Десна, Болва',
        54.0, 52.0, 31.0, 35.5, 9, 13),
    _Entry('kostroma', 'Кострома',
        'Волга, Кострома-река',
        59.0, 57.2, 39.5, 46.0, 9, 13, isTerrain: true),
    _Entry('vologda', 'Вологда',
        'Сухона, Белое озеро, Кубенское',
        61.5, 58.5, 35.5, 44.5, 9, 13, isTerrain: true),
    _Entry('arkhangelsk', 'Архангельск',
        'Северная Двина, Белое море',
        66.0, 61.0, 36.0, 50.0, 8, 12, isTerrain: true),

    // === Юг ===
    _Entry('volgograd', 'Волгоград',
        'Волго-Донской канал, Цимлянское вдхр',
        51.0, 47.5, 41.0, 47.0, 9, 13, isTerrain: true),
    _Entry('astrakhan', 'Астрахань',
        'Волго-Ахтубинская пойма, Каспий',
        49.0, 45.2, 44.5, 49.5, 9, 13),
    _Entry('stavropol', 'Ставрополь',
        'Пятигорск, Кавминводы',
        46.5, 43.5, 40.5, 45.5, 9, 13, isTerrain: true),
    _Entry('crimea', 'Крым',
        'Керчь, Ялта, Севастополь, Сиваш',
        46.3, 44.2, 32.5, 36.7, 9, 13, isTerrain: true),
    _Entry('sochi', 'Сочи / Красная Поляна',
        'Черноморское побережье, Кавказ',
        44.3, 43.0, 39.0, 41.2, 10, 14, isTerrain: true),

    // === Поволжье / Урал ===
    _Entry('samara', 'Самара',
        'Волга, Жигули, Самарская Лука',
        54.5, 52.5, 48.5, 52.5, 9, 13, isTerrain: true),
    _Entry('saratov', 'Саратов',
        'Волга, Саратовское вдхр',
        53.0, 50.5, 44.0, 48.5, 9, 13),
    _Entry('ulyanovsk', 'Ульяновск',
        'Волга, Свияга',
        55.0, 53.0, 46.5, 50.5, 9, 13),
    _Entry('cheboksary', 'Чебоксары',
        'Чувашия, Волга, Сура',
        56.7, 54.5, 45.5, 49.0, 9, 13),
    _Entry('izhevsk', 'Ижевск',
        'Удмуртия, Кама',
        58.5, 56.5, 51.5, 55.0, 9, 13),
    _Entry('perm', 'Пермь',
        'Кама, Чусовая, Камское вдхр',
        60.5, 57.0, 54.0, 60.0, 8, 13, isTerrain: true),
    _Entry('ufa', 'Уфа',
        'Башкортостан, Белая',
        56.5, 52.5, 52.5, 58.5, 9, 13, isTerrain: true),
    _Entry('orenburg', 'Оренбург',
        'Урал, Бузулук',
        54.0, 50.5, 52.0, 61.5, 9, 13),
    _Entry('magnitogorsk', 'Магнитогорск',
        'Южный Урал, Верхнеуральское вдхр',
        54.5, 52.0, 57.5, 60.5, 9, 13, isTerrain: true),
    _Entry('chelyabinsk', 'Челябинск',
        'Миасс, Тургояк, Увильды',
        56.0, 53.5, 58.5, 63.5, 9, 13, isTerrain: true),
    _Entry('kirov', 'Киров',
        'Вятка, Чепца',
        61.0, 56.5, 46.5, 53.0, 9, 13, isTerrain: true),
    _Entry('yoshkar', 'Йошкар-Ола (Марий Эл)',
        'Малая Кокшага, Волга',
        57.5, 55.5, 46.0, 50.0, 9, 13),
    _Entry('saransk', 'Саранск (Мордовия)',
        'Сура, Мокша',
        55.5, 53.5, 42.0, 47.0, 9, 13),
    _Entry('penza', 'Пенза',
        'Сура, Хопёр',
        54.5, 52.5, 42.5, 47.0, 9, 13),

    // === Сибирь ===
    _Entry('omsk', 'Омск',
        'Иртыш, Омь',
        56.5, 53.5, 70.5, 76.0, 9, 13),
    _Entry('tomsk', 'Томск',
        'Томь, Обь, кедры',
        59.0, 55.5, 80.0, 88.5, 9, 13, isTerrain: true),
    _Entry('kemerovo', 'Кемерово',
        'Кузбасс, Томь',
        57.5, 52.0, 84.5, 89.5, 9, 13),
    _Entry('tyumen', 'Тюмень',
        'Тура, Тобол',
        59.0, 55.0, 64.5, 72.0, 9, 13),
    _Entry('khanty', 'Ханты-Мансийск / Сургут',
        'Обь-Иртышская равнина',
        63.5, 59.5, 65.0, 80.0, 8, 12, isTerrain: true),
    _Entry('yamalo', 'Ямало-Ненецкий АО',
        'Ямал, Обская губа',
        73.0, 62.0, 62.0, 85.0, 7, 11, isTerrain: true),
    _Entry('altai_resp', 'Горный Алтай',
        'Катунь, Телецкое озеро, Белуха',
        53.0, 49.0, 83.0, 90.0, 8, 13, isTerrain: true),
    _Entry('tyva', 'Тыва',
        'Верховья Енисея, саянские хребты',
        53.5, 49.5, 88.5, 99.0, 8, 12, isTerrain: true),
    _Entry('khakasia', 'Хакасия',
        'Енисей, Красноярское вдхр',
        55.0, 51.0, 88.0, 91.5, 9, 13, isTerrain: true),
    _Entry('irkutsk', 'Иркутск',
        'Ангара, Иркутское вдхр',
        56.5, 51.0, 100.0, 108.0, 8, 13, isTerrain: true),
    _Entry('buryatia', 'Бурятия / Улан-Удэ',
        'Селенга, дельта, восточный Байкал',
        57.0, 49.5, 97.5, 116.5, 8, 12, isTerrain: true),

    // === Дальний Восток ===
    _Entry('yakutsk', 'Якутия / Якутск',
        'Лена, Колыма, Оймякон',
        72.0, 55.5, 105.0, 155.0, 7, 11, isTerrain: true),
    _Entry('magadan', 'Магадан / Колыма',
        'Охотское море, Колыма',
        66.0, 58.0, 144.0, 163.0, 8, 12, isTerrain: true),
    _Entry('kamchatka', 'Камчатка',
        'Ключевская сопка, Кроноцкое озеро',
        61.5, 50.5, 155.5, 165.0, 7, 12, isTerrain: true),
    _Entry('sakhalin', 'Сахалин',
        'Охотское и Японское моря',
        54.5, 45.5, 141.0, 145.0, 9, 13, isTerrain: true),
    _Entry('chukotka', 'Чукотка / Анадырь',
        'Беринг, Уэлен',
        70.0, 62.0, 170.0, 180.0, 7, 11, isTerrain: true),
    _Entry('khabarovsk', 'Хабаровск',
        'Амур, Уссури',
        52.0, 43.5, 130.0, 140.5, 8, 13, isTerrain: true),
    _Entry('amur', 'Амурская область / Благовещенск',
        'Амур, Зея',
        58.0, 49.0, 120.0, 136.0, 8, 12, isTerrain: true),

    // === Кавказ ===
    _Entry('dagestan', 'Дагестан',
        'Каспий, Сулак, Самур',
        44.5, 41.0, 45.0, 48.5, 9, 13, isTerrain: true),
    _Entry('chechnya', 'Чечня / Грозный',
        'Терек, Аргун',
        44.0, 42.5, 44.5, 46.5, 9, 13, isTerrain: true),
    _Entry('osetia', 'Северная Осетия',
        'Терек, Владикавказ',
        43.5, 42.5, 43.5, 45.0, 10, 14, isTerrain: true),
    _Entry('kabardino', 'Кабардино-Балкария / Эльбрус',
        'Черек, Баксан',
        44.0, 42.5, 41.5, 44.5, 9, 13, isTerrain: true),
    _Entry('karachay', 'Карачаево-Черкесия / Домбай',
        'Теберда, Кубань исток',
        44.5, 42.5, 40.0, 43.5, 9, 13, isTerrain: true),
    _Entry('adygea', 'Адыгея',
        'Лагонаки, Белая',
        45.5, 43.5, 38.5, 41.0, 10, 14, isTerrain: true),

    // === Север европейской РФ ===
    _Entry('karelia_full', 'Карелия (полная)',
        'Ладога, Онега, Белое море, Водлозеро',
        67.0, 60.5, 29.5, 37.5, 8, 12, isTerrain: true),
    _Entry('murmansk', 'Мурманская область',
        'Кольский, Хибины, Баренцево море',
        70.0, 66.0, 28.0, 41.0, 8, 12, isTerrain: true),
    _Entry('komi', 'Коми',
        'Печора, Уральский хребет',
        68.5, 59.0, 45.0, 67.0, 7, 11, isTerrain: true),
    _Entry('nenec', 'Ненецкий АО',
        'Печора, арктическое побережье',
        71.0, 65.5, 43.0, 62.0, 7, 11, isTerrain: true),

    // === Крупные водоёмы — отдельные пресеты ===
    _Entry('baikal', 'Озеро Байкал',
        'Всё озеро + окрестности',
        55.9, 51.4, 103.5, 110.0, 8, 13, isTerrain: true),
    _Entry('ladoga', 'Ладожское озеро',
        'Ладога + северные шхеры',
        62.0, 60.0, 29.5, 33.0, 9, 13, isTerrain: true),
    _Entry('onega', 'Онежское озеро',
        'Кижи, Петрозаводск',
        63.5, 60.5, 33.5, 37.0, 9, 13, isTerrain: true),
    _Entry('rybinsk', 'Рыбинское водохранилище',
        'Верхняя Волга + Шексна + Молога',
        59.0, 57.5, 37.5, 40.0, 10, 14, isTerrain: true),
    _Entry('cheboksary_res', 'Чебоксарское вдхр',
        'Нижегородская, Марий Эл',
        57.0, 55.5, 44.0, 48.5, 10, 14),
    _Entry('volgograd_res', 'Волгоградское вдхр',
        'Саратов-Волгоград, рыбалка на судака',
        51.7, 48.5, 44.0, 47.5, 9, 13),
    _Entry('psk_chud', 'Псковско-Чудское',
        'Псковская + Эстония',
        59.0, 57.5, 27.0, 28.8, 10, 14, isTerrain: true),
    _Entry('seliger', 'Селигер',
        'Озёрная система Осташкова',
        57.5, 56.8, 32.5, 34.0, 11, 15, isTerrain: true),
    _Entry('teletsk', 'Телецкое озеро',
        'Горный Алтай',
        52.0, 51.3, 87.0, 89.0, 11, 15, isTerrain: true),
  ];
}

class _Entry {
  const _Entry(
    this.id,
    this.name,
    this.description,
    this.n,
    this.s,
    this.w,
    this.e,
    this.zMin,
    this.zMax, {
    this.isTerrain = false,
  });

  final String id;
  final String name;
  final String description;
  final double n, s, w, e;
  final int zMin, zMax;

  /// If true — use OpenTopoMap (terrain/relief) instead of plain OSM schema.
  final bool isTerrain;
}
