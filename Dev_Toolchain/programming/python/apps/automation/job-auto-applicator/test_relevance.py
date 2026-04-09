from job_applicator_final import ProductionJobApplicator
from config import COMPANIES

app = ProductionJobApplicator()

print("\n" + "="*70)
print("CHECKING ALL COMPANIES FOR RELEVANCE")
print("="*70)

for i, company in enumerate(COMPANIES, 1):
    relevant, reason = app._is_job_relevant(company)
    was_sent, send_reason = app._was_recently_sent(company)
    
    print(f"\n{i}. {company['name']}")
    print(f"   Position: {company['position']}")
    print(f"   Location: {company['location']}")
    print(f"   Relevance: {'PASS' if relevant else 'FAIL'} - {reason}")
    print(f"   Cooldown: {'BLOCKED' if was_sent else 'OK'} - {send_reason}")

print("\n" + "="*70)
print(f"SUMMARY: {sum(1 for c in COMPANIES if app._is_job_relevant(c)[0])} / {len(COMPANIES)} companies are relevant")
print("="*70)
