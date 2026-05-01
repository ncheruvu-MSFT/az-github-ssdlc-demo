import { Component } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';

@Component({
  selector: 'app-nav',
  standalone: true,
  imports: [RouterLink, RouterLinkActive],
  template: `
    <nav class="navbar">
      <div class="navbar-brand">
        <span class="logo">🔒</span>
        <span class="title">SSDLC Demo</span>
      </div>
      <ul class="navbar-links">
        <li><a routerLink="/products" routerLinkActive="active">Products</a></li>
      </ul>
    </nav>
  `,
  styles: [`
    .navbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0.75rem 2rem;
      background: #0078d4;
      color: white;
    }
    .navbar-brand {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      font-size: 1.25rem;
      font-weight: 600;
    }
    .navbar-links {
      list-style: none;
      display: flex;
      gap: 1rem;
      margin: 0;
      padding: 0;
    }
    .navbar-links a {
      color: white;
      text-decoration: none;
      padding: 0.25rem 0.75rem;
      border-radius: 4px;
    }
    .navbar-links a.active, .navbar-links a:hover {
      background: rgba(255, 255, 255, 0.2);
    }
  `],
})
export class NavComponent {}
