import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ledger_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../widgets/person_avatar.dart';
import 'person_ledger_screen.dart';
import 'add_edit_person_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final people = provider.filteredPeople;

    return Scaffold(
      appBar: AppBar(
        title: const Text('মানুষ'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => provider.setSearchQuery(v),
                decoration: InputDecoration(
                  hintText: 'নাম বা ফোন নাম্বার খুঁজুন',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            provider.setSearchQuery('');
                          },
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: people.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            provider.searchQuery.isEmpty
                                ? 'কোনো ব্যক্তি যুক্ত করা হয়নি'
                                : 'কোনো ফলাফল পাওয়া যায়নি',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                      itemCount: people.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final person = people[index];
                        final balance = provider.personBalancePaisa(person.id);
                        final color = balance > 0
                            ? AppColors.receivableGreen
                            : balance < 0
                                ? AppColors.payableRed
                                : Colors.grey;
                        return ListTile(
                          leading: PersonAvatar(
                            name: person.name,
                            photoPath: person.photoPath,
                          ),
                          title: Text(
                            person.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: person.phone != null
                              ? Text(person.phone!)
                              : null,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Money.formatPaisa(balance.abs()),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                              Text(
                                balance > 0
                                    ? 'পাবো'
                                    : balance < 0
                                        ? 'দেবো'
                                        : 'সমান',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PersonLedgerScreen(personId: person.id),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditPersonScreen()),
        ),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
